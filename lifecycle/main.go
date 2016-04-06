package main

import (
	"encoding/json"
	"flag"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/sqs"
)

const (
	instanceTerminatingEvent = "autoscaling:EC2_INSTANCE_TERMINATING"
)

const (
	pidPollFrequency   = time.Second * 2
	heartbeatFrequency = time.Second * 10
)

type lifecycleEvent struct {
	AutoScalingGroupName string    `json:"AutoScalingGroupName"`
	Time                 time.Time `json:"Time"`
	EC2InstanceID        string    `json:"EC2InstanceId"`
	LifecycleActionToken string    `json:"LifecycleActionToken"`
	LifecycleTransition  string    `json:"LifecycleTransition"`
	LifecycleHookName    string    `json:"LifecycleHookName"`
}

type message struct {
	*sqs.Message
	Event lifecycleEvent
}

type pidPoller struct {
	process func() (*os.Process, error)
	cond    *sync.Cond
	running bool
}

func newPidPoller(pid int) *pidPoller {
	return &pidPoller{
		process: func() (*os.Process, error) { return os.FindProcess(pid) },
		cond:    sync.NewCond(&sync.Mutex{}),
		running: true,
	}
}

func newPidFilePoller(pidFile string) *pidPoller {
	return &pidPoller{
		process: func() (*os.Process, error) {
			b, err := ioutil.ReadFile(pidFile)
			if err != nil {
				return nil, err
			}
			pid, err := strconv.Atoi(string(b))
			if err != nil {
				return nil, err
			}
			return os.FindProcess(pid)
		},
		cond:    sync.NewCond(&sync.Mutex{}),
		running: true,
	}
}

func (pp *pidPoller) Start() {
	go func() {
		for _ = range time.NewTicker(pidPollFrequency).C {
			process, err := pp.process()
			if err != nil {
				log.Fatal(err)
				continue
			}
			pp.cond.L.Lock()
			if process.Signal(syscall.Signal(0)) != nil {
				pp.running = false
				pp.cond.Broadcast()
			}
			pp.cond.L.Unlock()
		}
	}()
}

func (pp *pidPoller) Shutdown() error {
	process, err := pp.process()
	if err != nil {
		return err
	}
	return process.Signal(syscall.Signal(syscall.SIGTERM))
}

func (pp *pidPoller) Wait() {
	pp.cond.L.Lock()
	for pp.running {
		pp.cond.Wait()
	}
	pp.cond.L.Unlock()
}

func main() {
	var (
		sqsQueue   = flag.String("queue", "", "The lifecycle SQS queue")
		instanceID = flag.String("instanceid", "", "The instance id to filter events by")
		pid        = flag.Int("pid", 0, "The process pid to monitor")
		pidFile    = flag.String("pidfile", "", "A pid file containing a pid to monitor")
	)

	flag.Parse()

	if *sqsQueue == "" {
		log.Fatal("Must provide a value for -queue")
	}

	if *instanceID == "" {
		log.Fatal("Must provide a value for -instanceid")
	}

	sqsSvc := sqs.New(session.New())
	autoscaleSvc := autoscaling.New(session.New())

	var poller *pidPoller
	if *pid != 0 {
		poller = newPidPoller(*pid)
	} else if *pidFile != "" {
		poller = newPidFilePoller(*pidFile)
	} else {
		log.Fatal("Either pid or pidfile must be provided")
	}

	for {
		messages, err := receiveMessages(sqsSvc, *sqsQueue)
		if err != nil {
			log.Println(err)
			continue
		}

		for _, m := range messages {
			if !matchMessage(m.Event, *instanceID) {
				if err = releaseMessage(sqsSvc, *sqsQueue, m.Message); err != nil {
					log.Println(err)
				}
				continue
			}

			log.Printf("Handling %s event for %s", m.Event.LifecycleTransition, m.Event.EC2InstanceID)

			hbt := time.NewTicker(heartbeatFrequency)
			go func() {
				for _ = range hbt.C {
					log.Println("Heartbeat fired")
					if err := sendHeartbeat(autoscaleSvc, m.Event); err != nil {
						log.Println(err)
					}
				}
			}()

			log.Printf("Shutting down buildkite-agent")
			if err = poller.Shutdown(); err != nil {
				log.Println("Failed to shutdown buildkite-agent:", err)
			} else {
				log.Printf("Waiting for buildkite-agent to stop")
				poller.Wait()
			}

			hbt.Stop()

			log.Printf("Completing EC2 Lifecycle event")
			if err := completeLifecycle(autoscaleSvc, m.Event); err != nil {
				log.Println(err)
			}

			log.Printf("Deleting SQS message")
			if err = deleteMessage(sqsSvc, *sqsQueue, m.Message); err != nil {
				log.Println(err)
			}
		}
	}
}

func matchMessage(e lifecycleEvent, instanceID string) bool {
	switch {
	case e.LifecycleTransition != instanceTerminatingEvent:
		return false
	case instanceID != "" && instanceID != e.EC2InstanceID:
		return false
	}
	return true
}

func receiveMessages(svc *sqs.SQS, queue string) (msgs []message, err error) {
	resp, err := svc.ReceiveMessage(&sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(queue),
		MaxNumberOfMessages: aws.Int64(10),
		WaitTimeSeconds:     aws.Int64(20),
		VisibilityTimeout:   aws.Int64(60),
	})
	if err != nil {
		return nil, err
	}

	for _, m := range resp.Messages {
		var e lifecycleEvent
		if err := json.Unmarshal([]byte(*m.Body), &e); err != nil {
			return nil, err
		}
		msgs = append(msgs, message{m, e})
	}

	return msgs, nil
}

func deleteMessage(svc *sqs.SQS, queue string, msg *sqs.Message) error {
	_, err := svc.DeleteMessage(&sqs.DeleteMessageInput{
		QueueUrl:      aws.String(queue),
		ReceiptHandle: msg.ReceiptHandle,
	})
	return err
}

func releaseMessage(svc *sqs.SQS, queue string, msg *sqs.Message) error {
	_, err := svc.ChangeMessageVisibility(&sqs.ChangeMessageVisibilityInput{
		QueueUrl:          aws.String(queue),
		ReceiptHandle:     msg.ReceiptHandle,
		VisibilityTimeout: aws.Int64(0),
	})
	return err
}

func sendHeartbeat(svc *autoscaling.AutoScaling, e lifecycleEvent) error {
	_, err := svc.RecordLifecycleActionHeartbeat(&autoscaling.RecordLifecycleActionHeartbeatInput{
		AutoScalingGroupName: aws.String(e.AutoScalingGroupName),
		LifecycleHookName:    aws.String(e.LifecycleHookName),
		InstanceId:           aws.String(e.EC2InstanceID),
		LifecycleActionToken: aws.String(e.LifecycleActionToken),
	})
	if err != nil {
		return err
	}
	return nil
}

func completeLifecycle(svc *autoscaling.AutoScaling, e lifecycleEvent) error {
	_, err := svc.CompleteLifecycleAction(&autoscaling.CompleteLifecycleActionInput{
		AutoScalingGroupName:  aws.String(e.AutoScalingGroupName),
		LifecycleHookName:     aws.String(e.LifecycleHookName),
		InstanceId:            aws.String(e.EC2InstanceID),
		LifecycleActionToken:  aws.String(e.LifecycleActionToken),
		LifecycleActionResult: aws.String("CONTINUE"),
	})
	if err != nil {
		return err
	}
	return nil
}
