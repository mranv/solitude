<h1 align="center">
<br>
<img src=../assets/disk-encryption.png height="400" >
<br>
<strong>Disk Solitude: A Script Collection for Disk Encryption and Decryption</strong>
</h1>

## Overview

Disk Solitude comprises a set of shell scripts designed to manage disk encryption and decryption, along with logging functionalities, primarily for Linux systems. These scripts enable users to control disk encryption status and maintain detailed system logs for enhanced security.

## Features

- **Linux Compatibility:** Designed to operate seamlessly on Linux platforms, ensuring compatibility for various Linux distributions.
- **Disk Management:** Provides tools to encrypt and decrypt specific disks, allowing users to control data access and protection as needed.
- **Logging Functionality:** Incorporates logging capabilities to record encryption and decryption events, facilitating monitoring and analysis of disk activities.
- **Configurability:** Offers flexibility for customization, allowing users to adjust disk encryption and logging settings within the scripts according to their preferences.

## Usage

1. **Installation:** Download the repository and execute the desired script based on your disk management needs.
2. **Configuration:** Customize disk encryption and logging settings within the scripts according to your preferences.
3. **Execution:** Run the scripts to implement the configured settings and manage disk encryption and logging on your system.

### Encrypting a Disk

To encrypt a disk, use the `encryptdisk.sh` script. Ensure you replace the placeholder disk identifier (`/dev/sdX`) with the actual disk you intend to encrypt.

```bash
./encryptdisk.sh
```

### Decrypting a Disk

To decrypt a disk, use the `decryptdisk.sh` script. Ensure you replace the placeholder disk identifier (`/dev/sdX`) with the actual disk you intend to decrypt.

```bash
./decryptdisk.sh
```

## Contribution

Contributions and feedback are welcome to enhance the functionality and reliability of Disk Solitude. Users are encouraged to submit pull requests or report issues for improvements or bug fixes.

## Disclaimer

Disk Solitude is provided as-is, without warranty or guarantee of performance. Users should review and understand the scripts before execution and use them responsibly.

## Stay Connected

Follow us on GitHub to stay informed about updates and releases. Your support and engagement are appreciated!
