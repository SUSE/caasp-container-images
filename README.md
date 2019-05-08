# CaaSP Container Images

This repository include the image definitions of CaaSP Container Images. Images
are built in Open Build Service using KIWI. Thus the sources included in this
repository are mainly the KIWI description files for each image.

Each subfolder matching he `caasp-*-image` pattern represents a single image.
`ci` subfolder includes the continuous integration related tools.

## Development

In order to create the files submitted to OBS pleas use the following:

```bash
make IMG=<img_folder> suse-package
```

This command will create the files needed for OBS in
`ci/packaging/suse/obs_files`.

Alternatively, inside any image subfolder there is no need to specify the `IMG`
parameter. In that case the developer can just call:

```bash
make suse-package
```
