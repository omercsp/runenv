# Run Environment Script

## What is this?

A tool to automatically run the correct container, with the correct arguments and the correct command according to the directory it is invoked from. The actual command to execute in the container is passed as CLI argument or set in a configuration file (with many other possible settings).

## What for?

The motivation for this tool came from my need to build different projects, using different tool-chains, for different platforms. Like many others, I used containers as build platforms for that reason, but still had to keep track keep track of where I am, what image I need to run, with what settings in order to build for the correct target. (The terms 'build' and 'target' are used here as this script was originally written to help building project using `make`, but the command can be anything).

For example, assume a gcc C++ project that need to be built for a CentOS Linux with specific version using `make`. Build containers based on the target platform (CentOS, in this case) can help here. But still I need to remember how exactly this is done every time I work on this project. Now add to it another project for a different platform and a different build command (say, `scons`). Now there's a need to keep track of on which project is built, which platform (container) to use for it, and which command to run it.

Enter the `runenv.sh` script.


## How does it help?

The script uses a configuration file named `.runenv.conf` that defines all that there is to be defined running in this particular folder. Once set, no need to remember anything anymore. Just invoke the `runenv.sh` script, and everything is ran as expected. This allows consistency over all projects. Instead of running specific containers and scripts for each project, the same method and configuration is used. It also allows to run a different commands in the same environment (See the `RE_CMD` setting and explanation below) which is useful.

## Is this new?

Probably not. Didn't check. Projects like this one are likely to exist somewhere, and some people might find this redundant, but it works for me and might work for anyone who looks for a (relatively) simple local solution.

## How do I work with it?

1. Place the `runenv.sh` somewhere in you path (say,  `${HOME}/.local/bin`)
2. Create a configuration file in the desired project folder - copy the `dot-runenv.conf.skel` to your project folder as `.runenv.conf`, and edit the file according to your needs.

And you are set to go. Now all that needs to be done is to run `runenv.sh` and the right image with the right command is executed. Repeat step 2 for every project/folder you need to have it's own container/command/setting for. Overriding the command in set in the configuration file is done by running `runenv.sh <CMD>`.

### Example

Following the previous example, assume that under `/opt/project` folder, there's a small C++ project to be built with a container from an image named `localhost:mybuilder`. To run this configuration correctly one needs to run the container with all kind of setting to make the build as expected:

1. The image
2. Volume mapping
3. Working directory
4. etc.

So if the command is simple, it might look something like this:

```
project $ podman run -it -v $(pwd):$(pwd) -w $(pwd) localhost/mybuilder:latest make
Building 'a.out'
CXX	main.o
LD	a.out
project $
```

If the run command is more complex, this might get exhausting. Using `runenv.sh` is there to simplify this process.

First, create a `.runenv.conf` file in the project directory, then populate it with the appropriate settings (see the `dot-runenv.conf.skel` file for settings description):

```bash
RE_IMAGE=localhost/mybuilder:latest
RE_CMD=make
RE_VOL_MAPPING=$(pwd):$(pwd)
RE_USE_CUR_CWD=1
```

Then, just run the `runenv.sh`:

```
project $ runenv.sh
 __             ___
|__) |  | |\ | |__  |\ | \  /
|  \ \__/ | \| |___ | \|  \/

Configuration file: /opt/project/.runenv.conf
Tool: podman
Image: localhost/mybuilder:latest
Run flags: -w=/opt/project
Volume: /opt/project:/opt/project
Command: 'make'
==============================================================================
Building 'a'
CC main.o
LD a
==============================================================================
Done!
project $

```

Now you can just build the project with the right container, the right setting and the right command without the need to remember anything. With many folders like this one, as well as folder which aren't containers based this can be handy. Always run you command through the script, and the correct environment will be set for it.

## A few notes about configuration

The full configuration documentation is inside `dot-runenv.conf.skel`, but some things are worth mentioning regarding the script behavior

1. All configuration files are actually bash scripts sourced by the script, so keep the format as `<SETTING>=<VALUE>`. No spaces around the assignment operator, or it won't work. This also means bash internals and program execution can be used and added here.
2. The script first attempts to read a global configuration file `${HOME}/.config/.runenv.conf`.
3. Afterwards the script attempts to search for a `.runenv.sh` on every folder from the current working directory all the way up to root. If one is found, the search is stopped. Settings found in this configuration file override those from the global configuration file.
4. Other then the command setting (`RE_CMD`), all other settings can be overridden by environment variables with a `_` prefix. So setting `_RE_IMAGE` will override the `RE_IMAGE` found in any of the configuration files. This is useful for debugging and to overriding from from IDEs and such.
5. The command setting `RE_CMD` is overridden by the tool CLI arguments, so `runenv.sh echo "foo"` will override whatever the configuration files defined as `RE_CMD` with `echo "foo"`.

## Supported systems

I wrote this tool for me, so it only tested on Linux - Fedora, in my case - with `podman` as a container running tool but it should be compatible to, or easy to port to, any docker-like tool in a `bash` supported environment. There's a setting for changing the running tool, but I have yet to test it.

Docker based configuration will probably need a user ID and group ID run/exec settings.

## License

MIT
