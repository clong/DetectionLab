# Continuous Integration

The files in this directory are used to bootstrap an Ubuntu 16.04 baremetal server
for continuous integration testing by installing the prerequisites needed for
Detection Lab. After the prerequisites are installed, the build script is called
and the build will begin in a tmux session.

## Understanding the build process

Once a PR is created, the contents of that PR will be copied to a CircleCI worker to be tested.
The CircleCI worker will evaluate which files have been modified and set environment variables accordingly. There are 4 possible options and 3 different tests:

1. Code in both the Packer and Vagrant directories was modified
  * In this case, the CircleCI worker will execute `ci/circle_workflows/packer_and_vagrant_changes.sh`
2. Code in neither the Packer and Vagrant directories was modified
  * In this case, the CircleCI worker will execute the default test `ci/circle_worker/vagrant_changes.sh`
3. Code in only the Packer directory was modified
  * In this case, the CircleCI worker will execute `ci/circle_worker/packer_changes.sh`
4. Code in only the Vagrant directory was modified
  * In this case, the CircleCI worker will execute `ci/circle_worker/vagrant_changes.sh`

## Test Case Walkthroughs

### packer_and_vagrant_changes.sh
1. Spins up a single Packet server
2. Bootstraps the Packet server by calling `ci/build_machine_bootstrap.sh` with no arguments
3. Builds the Windows10 and Windows2016 images one at a time
4. Moves the resulting boxes to the Boxes directory
5. Brings each Vagrant host online one-by-one
6. CircleCI records the build results from the Packet server

### vagrant_changes.sh
1. Spins up a single Packet server
2. Bootstraps the Packet server by calling `ci/build_machine_bootstrap.sh` with the `--vagrant-only` argument
3. Downloads the pre-build Windows10 and Windows2016 boxes from https://detectionlab.network directly to the Boxes directory
4. Brings each Vagrant host online one-by-one
5. CircleCI records the build results from the Packet server


### packer_changes.sh
1. Spins up two separate Packet servers to allow the Packer boxes to be built in parallel
2. Bootstraps each packet Server by calling `ci/build_machine_bootstrap.sh` with the `--packer-only` argument
3. Starts the Packer build process on each server
4. CircleCI records the build result from each Packet server

```
                                             +------------+
                                             |            |
                                             |            |
                                             |            |
                                             |   Github   |
                                             |            |
                                             |            |
                                             +------+-----+
                                                    |
                                                    |
                                                    | Pull Request
                                                    |
                                                    v
                                             +------+-----+
                                             |            |
                                             |            |
                                             |   Circle   |
              +----------------------------->|   Worker   |
              |                              |            |
              |                              |            |
              |                              |            |
              |                              +------+-----+
              |                                     |
              |                                     | Code changes are evaluated
              |                                     | to determine which test suite
              |                                     | to run
              |                                     |
              |                                     v
              |                    +----------------+--------------+
Circle Worker |                    | packer_and_vagrant_changes.sh |
quries for    |                    | vagrant_changes.sh            |
build results |                    | packer_changes.sh             |        
              |                    +----------------+--------------+             
              |                                     |
              |                                     |
              |          |                          |
              |                                     |
              |                                     |
              |                                     |
              |                                     |
              |                                     |  1. Provision Packet server(s)
              |                                     |  2. Copy repo to server
              |                                     |  3. Run server bootstrap
              |                                     |  4. Bootstrap calls build.sh with
              |                                     |  the appropriate arguments
              |                                     |
              |                                     |
              |                           +---------v---------+
              |                           |                   |
              |                           |                   |
              |                           |                   |
              +-------------------------->|   Packet Server   |
                                          |                   |
                                          |                   |
                                          |                   |
                                          +-------------------+

```
