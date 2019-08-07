var AWS = require('aws-sdk')
var response = require('./cfn-response.js')
exports.handler = function(event, context, callback) {
  console.log('Request received:\n', JSON.stringify(event))
  var resProps = event.ResourceProperties,
    sourceImageId = resProps.SourceImageId,
    sourceRegion = resProps.SourceRegion,
    kmsKeyId = resProps.KmsKeyId,
    physicalId = event.PhysicalResourceId

  function success(data) {
    return response.send(
      event,
      context,
      response.SUCCESS,
      { Id: physicalId },
      physicalId
    )
  }
  function failed(e) {
    return response.send(event, context, response.FAILED, e, physicalId)
  }

  // Call ec2.waitFor, continuing if not finished before Lambda function timeout.
  function wait(waiter) {
    console.log('Waiting: ', JSON.stringify(waiter))
    event.waiter = waiter
    event.PhysicalResourceId = physicalId
    var request = ec2.waitFor(waiter.state, waiter.params)
    setTimeout(() => {
      request.abort()
      console.log(
        'Timeout reached, continuing function. Params:\n',
        JSON.stringify(event)
      )
      var lambda = new AWS.Lambda()
      lambda
        .invoke({
          FunctionName: context.invokedFunctionArn,
          InvocationType: 'Event',
          Payload: JSON.stringify(event),
        })
        .promise()
        .then(data => context.done())
        .catch(err => context.fail(err))
    }, context.getRemainingTimeInMillis() - 5000)
    return request.promise().catch(err => {
      console.log('Error on waitFor: ', JSON.stringify(err))
      if (err.code == 'RequestAbortedError') {
        return new Promise(() => context.done())
      } else {
        return Promise.reject(err)
      }
    })
  }

  var ec2 = new AWS.EC2(),
    kms = new AWS.KMS()

  if (event.waiter) {
    wait(event.waiter)
      .then(data => success({}))
      .catch(err => failed(err))
  } else if (event.RequestType == 'Create' || event.RequestType == 'Update') {
    var Operations = [
      'Decrypt',
      'Encrypt',
      'GenerateDataKey',
      'GenerateDataKeyWithoutPlaintext',
      'CreateGrant',
      'DescribeKey',
      'ReEncryptFrom',
      'ReEncryptTo',
    ]
    var listGrantsParams = { KeyId: kmsKeyId }
    var checkGrantOperations = function(grant) {
      var hasAllOperations = true
      for (var i = 0; i < Operations.length; i++) {
        var op = Operations[i]
        if (grant.Operations.indexOf(op) === -1) {
          console.log('Grant found but does not have operation: ', op)
          hasAllOperations = false
        }
      }
      return hasAllOperations
    }
    var createGrantParams = {
      GranteePrincipal:
        'arn:aws:iam::775966183015:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot',
      KeyId: kmsKeyId,
      Operations,
    }
    var copyParams = {
      Name: 'buildkite-stack-encrypted',
      SourceImageId: sourceImageId,
      SourceRegion: sourceRegion,
      Description: 'Encrypted version of the buildkite agent AMI',
      Encrypted: true,
      KmsKeyId: kmsKeyId,
    }
    var hasGrant
    kms
      .listGrants(listGrantsParams)
      .promise()
      .then(({ Grants }) => {
        var grant
        for (var i = 0; i < Grants.length; i++) {
          grant = Grants[i]
          if (
            grant.GranteePrincipal.indexOf('AWSServiceRoleForEC2Spot') !== -1 &&
            checkGrantOperations(grant)
          ) {
            hasGrant = true
            console.log('Grant exists!')
            break
          }
        }
        if (hasGrant) Promise.resolve(grant)
        else return kms.createGrant(createGrantParams).promise()
      })
      .then(data => {
        console.log('Grant created or already existed: ', JSON.stringify(data))
        return ec2.copyImage(copyParams).promise()
      })
      .then(data =>
        wait({
          state: 'imageAvailable',
          params: { ImageIds: [(physicalId = data.ImageId)] },
        })
      )
      .then(data => success({}))
      .catch(err => failed(err))
  } else if (event.RequestType == 'Delete') {
    if (physicalId.indexOf('ami-') !== 0) {
      return success({})
    }
    ec2
      .describeImages({ ImageIds: [physicalId] })
      .promise()
      .then(data =>
        data.Images.length == 0
          ? success({})
          : ec2.deregisterImage({ ImageId: physicalId }).promise()
      )
      .then(data =>
        ec2
          .describeSnapshots({
            Filters: [
              {
                Name: 'description',
                Values: ['*' + physicalId + '*'],
              },
            ],
          })
          .promise()
      )
      .then(data =>
        data.Snapshots.length === 0
          ? success({})
          : ec2
              .deleteSnapshot({ SnapshotId: data.Snapshots[0].SnapshotId })
              .promise()
      )
      .then(data => success({}))
      .catch(err => failed(err))
  }
}
