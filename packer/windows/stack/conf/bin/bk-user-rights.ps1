# Adds and lists the user rights (privileges) assigned directly to an account,
# using the LSA policy API. Dot-source this file, then call
# [BkUserRights]::Add($Sid, "SeShutdownPrivilege") or [BkUserRights]::Get($Sid).

Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

public static class BkUserRights {
  [StructLayout(LayoutKind.Sequential)]
  struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }

  [StructLayout(LayoutKind.Sequential)]
  struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public int Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }

  [DllImport("advapi32.dll")] static extern uint LsaOpenPolicy(IntPtr systemName, ref LSA_OBJECT_ATTRIBUTES attributes, int access, out IntPtr handle);
  [DllImport("advapi32.dll")] static extern uint LsaAddAccountRights(IntPtr handle, byte[] sid, LSA_UNICODE_STRING[] rights, int count);
  [DllImport("advapi32.dll")] static extern uint LsaEnumerateAccountRights(IntPtr handle, byte[] sid, out IntPtr rights, out int count);
  [DllImport("advapi32.dll")] static extern uint LsaFreeMemory(IntPtr buffer);
  [DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr handle);
  [DllImport("advapi32.dll")] static extern int LsaNtStatusToWinError(uint status);

  const int POLICY_CREATE_ACCOUNT = 0x10;
  const int POLICY_LOOKUP_NAMES = 0x800;
  const uint STATUS_OBJECT_NAME_NOT_FOUND = 0xC0000034;

  static void Check(uint status) {
    if (status != 0) throw new Win32Exception(LsaNtStatusToWinError(status));
  }

  static IntPtr Open() {
    var attributes = new LSA_OBJECT_ATTRIBUTES();
    IntPtr handle;
    Check(LsaOpenPolicy(IntPtr.Zero, ref attributes, POLICY_CREATE_ACCOUNT | POLICY_LOOKUP_NAMES, out handle));
    return handle;
  }

  static byte[] SidBytes(string sid) {
    var identifier = new SecurityIdentifier(sid);
    var bytes = new byte[identifier.BinaryLength];
    identifier.GetBinaryForm(bytes, 0);
    return bytes;
  }

  public static void Add(string sid, string right) {
    var name = new LSA_UNICODE_STRING {
      Buffer = Marshal.StringToHGlobalUni(right),
      Length = (ushort)(right.Length * 2),
      MaximumLength = (ushort)((right.Length + 1) * 2)
    };
    IntPtr handle = Open();
    try {
      Check(LsaAddAccountRights(handle, SidBytes(sid), new[] { name }, 1));
    } finally {
      LsaClose(handle);
      Marshal.FreeHGlobal(name.Buffer);
    }
  }

  public static string[] Get(string sid) {
    IntPtr handle = Open();
    try {
      IntPtr rights;
      int count;
      uint status = LsaEnumerateAccountRights(handle, SidBytes(sid), out rights, out count);
      if (status == STATUS_OBJECT_NAME_NOT_FOUND) return new string[0];
      Check(status);
      try {
        var result = new string[count];
        int size = Marshal.SizeOf(typeof(LSA_UNICODE_STRING));
        for (int i = 0; i < count; i++) {
          var right = (LSA_UNICODE_STRING)Marshal.PtrToStructure(new IntPtr(rights.ToInt64() + i * size), typeof(LSA_UNICODE_STRING));
          result[i] = Marshal.PtrToStringUni(right.Buffer, right.Length / 2);
        }
        return result;
      } finally {
        LsaFreeMemory(rights);
      }
    } finally {
      LsaClose(handle);
    }
  }
}
"@
