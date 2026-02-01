# SCP and SSH-CAT File Transfer Notes

## SCP (Secure Copy Protocol)

`scp` copies files between hosts on a network. It uses ssh for data transfer, and uses the same authentication and provides the same security as ssh. Unlike rcp, scp will ask for passwords or passphrases if they are needed for authentication.

> **IMPORTANT:** You will not run SCP on a target box

### Basic Syntax
```
scp {you} {them}
```

### Upload
```bash
scp [/path/to/local/]<file> <user>@<remote_IP>:~/.
```

### Download
```bash
scp <user>@<remote_ip>:[/path/to/remote]<file> [/path/to/local/file]
```

### Via SSH (Using Control Socket)
```bash
scp -o ControlPath=/tmp/T1 -P 22 student9@127.0.0.1:/remote/path/file test
```

This would download the file `file` from the remote directory `/remote/path/` to your local machine, and save it to a file named `test`.

## SSH-CAT

Utilizing ssh's capability to execute a remote command and basic file redirection.

### Download
```bash
ssh <user>@<Remote_IP> "cat <file>" > <file>
```

### Upload
```bash
ssh <user>@<Remote_IP> "cat > <file>" < <file>
```
