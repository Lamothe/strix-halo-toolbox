# Strix Halo Toolbox

A ROCm 7.2.2 container environment for the Strix Halo with a working implementation of [TRELLIS.2](https://github.com/microsoft/TRELLIS.2) from Microsoft.

Tested on:

- Fedora 43
- Strix Halo (128 GB)

## Getting Started

Clone the repo and enter the root of the project.

```
git clone https://github.com/Lamothe/strix-halo-toolbox
cd strix-halo-toolbox
```

### Download Wheels

Run this once to save you from downloading them again.

```
./download_wheels.sh
```

### Build the Image

Run this once.

```
./build.sh
```

### Create the Container

Run this once. Note that you can call this script with an optional parameter of the container name (i.e. `./create.sh test`) otherwise it will default to `rocm-7.2`.

```
./create.sh
```

### Enter the Container

Note that you can call this script with an optional parameter of the container name (i.e. `./enter.sh test`) otherwise it will default to `rocm-7.2`.

```
./enter.sh
```

### Configure the Container

Once inside the container, you must configure your environment variables and activate the virtual environment. You need to run this every time you enter the container.

```
. configure.sh
```

### Set up Hugging Face Authentication

Once you are in the container, set your Hugging Face access token.
If you don't have a Hugging Face access token then log into Hugging Face and [create one](https://huggingface.co/settings/tokens).

```
export HF_TOKEN="<YOUR HF TOKEN>"
```

### Setup the Container

Run this once. This will take some time (5-10 minutes).

```
# This needs to be run inside the container.
./setup.sh
```

## Running

### TRELLIS.2

```
cd TRELLIS.2_rocm
python app.py
```

### ComfyUI

```
cd ComfyUI
python main.py
```

## Cleaning Up

First exit the container then run `cleanup.sh` (once again, with the optional container name). This will remove the container and force a git clean.

```
# Exit the container first.  NOTE: This will DELETE any uncommitted files!
./cleanup.sh
```
