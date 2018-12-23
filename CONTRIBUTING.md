# Contributing to DetectionLab

Please feel free to make contributions to DetectionLab that fit into any of the following categories:

* Bug fixes
* Improvements to existing configurations
* Feature additions/enhancements
* Tooling additions/improvements

The following types of changes should be maintained on a personal fork and should **not** submitted as a PR:

* [Switching out existing tooling based on personal taste](https://github.com/clong/DetectionLab/issues/43) (e.g. replacing Splunk with ELK)
* [Adding additional Boxes/VMs](https://github.com/clong/DetectionLab/issues/125)
* Any changes that result in drastically longer build times
* Any configurations that are not portable


### Pull requests

All contributions are submitted via pull requests open against the
[master](https://github.com/clong/DetectionLab/tree/master) branch. Pull requests are all reviewed and must pass continuous integration tests before being merged.

If you're unfamiliar with GitHub or how pull requests work, GitHub has a very easy to follow guide
that teaches you how to fork the project and submit your first PR. You can follow it
[here](https://guides.github.com/activities/forking/).

Once you submit your PR, it will be held for approval until someone manually approves the CI test on CircleCI.

If the test fails or the reviewer requests changes, please submit those changes by **appending new
commits** to your feature branch.

Once your pull request is approved and the CircleCI build passes, the PR is ready to merge. A maintainer will merge your PR into master at this point in time.

### Branches and tags

The DetectionLab repo contains only the [master](https://github.com/clong/DetectionLab/tree/master) branch. I don't keep feature or release branches.

## License

By contributing to DetectionLab you agree that your contributions will be licensed as defined on the
[LICENSE](LICENSE) file.
