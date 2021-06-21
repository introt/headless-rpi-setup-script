# Headless Raspberry Pi setup script

This script can write the image, mount it for modifications (like setting up wifi and key-based SSH logins including key generation) and clean up after itself.

## Configuration

You can either edit the script itself or create a configuration file. See `conf-example` for reference.

### Using a configuration file

The default location for a configuration file is `$HOME/.config/raspi`. You can also give a configuration file as an argument; this is sourced before any execution takes place and can thus override literally everything. Try running the script without arguments and with conf-example as an argument to see the difference. No destructive action is taken without prompting.
