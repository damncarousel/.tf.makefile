![.tf.makefile][splash]

> `make` commands for your terraform needs

This contains a series of `make` targets to aid in some basic terraform
management and bootstrapping.

__Note, this is still a work in progress.__


&nbsp;

---

## Installation

Copy [`.tf.makefile`][tfmakefile] into your project in your own way. *Note, it
should not be renamed.*

&nbsp;

Then `include` this file in your own `Makefile` as such (prefferably at the
bottom):

    include .tf.makefile

    #eof


*Note, the `#eof` line.*

Else, if you are starting fresh you can start off a new project with:

    $ make -f .tf.makefile .tf.makefile:init


This will create a `Makefile` for you with `.tf.makefile` included.


> NOTE, for Mac OS users, `gnu-make` and `gnu-sed` will be required for full
> compatibility. These can be installed easily via homebrew.


&nbsp;

---

## Usage/API

### Setting up your terraforms

---

#### tf:new

    $ make [{service-name}/]tf:new


`.tf.makefile` assumes a particular directory structure for your Terraform
projects.

This is the basic structure that would need to be employed.

    my-project/
        .templates/
            provider.tfvars
            variables.tfvars
        ._tf.makefile
        .tf.makefile
        Makefile
        provider.tf
        variables.tf


This struture can be automatically generated with

    $ make tf:new


*Note, the layout above is used for a flat (or single) service structure, where
you are working with one service or you want to keep everything in a single
directory.*

*Note, if you want to introduce `.tf.makefile` into your project, you can still
run `tf:new`, but please back up your `Makefile` if you already have one in
use.*


&nbsp;

For a multiple service project, the layout varies just slightly from the above.

    my-project/
        .templates/
            provider.tfvars
            variables.tfvars
        .tf.makefile
        Makefile
        provider.tf
        serivce-a/
            .templates/
                variables.tfvars
            ._tf.makefile
            Makefile
            variables.tf
        serivce-b/
            .templates/
                variables.tfvars
            ._tf.makefile
            Makefile
            variables.tf
        variables.tf


To generate the base structure for a multiple service project,

    $ make tf:new MULTI=true


*Note, the main difference between a single and multiple service project is the
multiple project does not include a generated `._tf.makefile` in the root
directory, as well as not including any Terraform generated targets against the
root directory, this will be explained shortly.*


Each service (`service-a, service-b`) can then be generated using

    $ make {service-name}/tf:new


Example

    $ make service-a/tf:new


*Note, you will notice that each service does not include it's own
`provider.tf` or a `provider.tfvars` (in the templates directory). It is
assumed that multiple service projects all share the same Provider.*


&nbsp;

---

#### .templates

    .templates/


Many of my projects are written for and deployed by third parties. Because of
this `.templates` provide a way to configure for a specific use case or
configuration while leaving your variables and terraform code unchanged.

A sample `.templates/variables.tfvars` may come packaged likes this

    # domain is the domain name configured to our nginx instance
    #
    #domain="production.domain.com"


And this would correspond to the variable you define in your `variables.tf`


    variable "domain" {
        default = "production.domain.com"
    }


Given this, if you are setting up a "staging" deployment, you can then
configure this value for your that particular use case

    # domain is the domain name configured to our nginx instance
    #
    domain="staging.domain.com"


*Note, `.templates/` files are copied over during the `tf:make` process
described below.*


&nbsp;

---

#### tf:make

    $ make [{service-name}/]tf:make


Once you are ready to plan or deploy or just check your work, `tf:make` will
setup your directory for you by,

1. Copying over the `.tfvars` in your `.templates` directory out to it's parent
   folder

        my-project/
            .templates/
                provider.tfvars
                variables.tfvars


    becomes

        my-project/
            .templates/
                provider.tfvars
                variables.tfvars
            .provider.tfvars
            .variables.tfvars


    These copied `.tfvars` can now be configured for your particular use case
    and will be used when calling `terraform` commands via the `-var-file=`
    flag.

    *Note, `tf:make` may be run a number of times, subsequent to the first run,
    copied `.tfvars` will not be overwritten. To overwrite existing `.tfvars`
    you can call `tf:make` with a `!` (bang).*

        $ make tf:make!


    Along with copying over `.tfvars` it also redefines the
    `{service-name}_VAR_FILES=` variable to ensure all are accounted for if you
    happen to add additional `.tfvars` files into your `.templates` directory.

    *Note, this variable can be found in the generated `._tf.makefile` and will
    looks something like*

        SERVICE-A_VAR_FILES= \
            -var-file=./.provider.tfvars \
            -var-file=./.variables.tfvars


&nbsp;

2. It runs `terraform init` to bring the terraform dependencies you defined
   into your project.


&nbsp;

3. If you are running `tf:make` on a service folder it will link your provider
   into that service as a `symlink`.

        my-project/
            ...
            provider.tf
            service-a/
                ...

    Given `service-a`, running

        $ make service-a/tf:make


    will produce

        my-project/
            ...
            provider.tf
            service-a/
                ...
                provider.tf -> /path/to/my-project/prvider.tf


*Note, you need to run `tf:make` on all services as well as the root directory.
This can be done with the convenience target `TODO tf:make:all`.*


## &nbsp;

### Deploying your terraforms

---

#### tf:plan

    $ make [{service-name}/]tf:plan


This is your standard target call to `terraform plan`, this will `-out=plan`.
And use the `{SERVICE-NAME}_VAR_FILES=` variables to include your `.tfvars`
files.


&nbsp;

---

#### tf:apply

    $ make [{service-name}/]tf:apply


This calls `terraform apply plan`, using the a `plan` you may have planned out
in an earlier `tf:plan`.

*Note, if there is no `plan` file, it will automatically run `tf:plan` to
create a plan output before running `terraform apply ...`.*

`tf:apply` will always use an existing `plan`. If you want enfore a "re-plan"
before applying, run `tf:apply` appended with a `!` (bang).

    $ make tf:apply!


&nbsp;

---

#### tf:destroy

    $ make [{service-name}/]tf:destroy


`tf:destroy` calls `terraform destroy` and will run through `terraform`'s
destroy process.

Because this is "undoable" `tf:destroy` adds an extra confirmation of it's own,
where it will ask you to submit a generated key. If the input key matches it
will proceed with the `terraform destroy` at which point you will be asked by
`terraform` itself to confirm once again.

*Note, there is no built-in `tf:destroy` target that requires no confirmation,
eg. `tf:destroy` appended with a `!` (bang).  But you can use the "private"
targets `tf:__destroy__` and build your own. But
you are on your own on this...*


## &nbsp;

### Shortcuts for You

---

There are a basic set of shortcuts that come generated as part of the `tf:new`
process.

    $ make {service-name}


This allows you to run `tf:apply!` for any "root" service or sub-service by
it's "name" (directory name).


&nbsp;

Single service example:

    my-project/
        ...
        ._tf.makefile
        .tf.makefile


You can call `tf:apply!` with

    $ make my-project


&nbsp;

In a multiple service example:

    my-project/
        ...
        .tf.makefile
        service-A/
            ...
        service-B/
            ...


You can call any one of your services' `tf:apply!` (`{service-name}/tf:apply!`)
with

    $ make service-A

    // equivalent to

    $ make service-A/tf:apply!


*Note, all of these commands are called from the "root" directory, you do not
have to `cd` into the service's directory to run these commands. __You can run
ALL your `tf` commands for ANY service from the "root" directory__.*

&nbsp;

---

#### But, I like to `cd` into things...

If you happen to want to `cd` and run commands in a service, the `plan`,
`apply` and `destroy` targets are available without the `tf:` prefix.

    $ $(pwd)
    => /path/to/my-project

    $ cd service-A
    $ make plan


You can, of course, continue to use the `tf:` prefix as well, if you wish.

    $ cd service-A
    $ make tf:plan


&nbsp;

---

## SSH

`.tf.makefile` comes with a few helpers to make SSHing into your boxes a bit
easier.


### Setting up SSH

---

To setup your project (or service) for SSH, a few steps need to be taken.

__Create a `.ssh` directory__

    $ make [{service-name}/]mkdir:.ssh


This will create a `.ssh` directory for you, where you keys will ultimately be
stored in.

*Note, we advise you source control the directory itsef, but ignore what's in
it. It can be done in git with*

__.gitignore__

    **/.ssh/**/*
    !**/.ssh/.gitkeep


__Generate your key__

    $ make [{service-name}/]ssh-keygen


This runs your standard `ssh-keygen` and stores the the keys in `.ssh/` as
`id_rsa`.

*Note, this key should be included into your deployments. I will not go into
details here as this will vary based on your terraforms.*


**Expose an `ipv4_address` output**

*Note, this may not be possible if your terraforms are in charge of deploying
multiple instances of something, ie. say a box in an AWS Auto Scaling Group.
You would have to manually enter your IP address, which you have the option to
do.*

But, if you do have a single box you want to access and don't want to look up
the IP address in your provider's console. Providing a terraform output
variable with the name `ipv4_address` will help with that.

An example might look like

    output "ipv4_address" {
        value = "${digitalocean_droplet.default.ipv4_address}"
    }


https://github.com/nowk/terraform-example/blob/master/droplet.tf


&nbsp;

### Doing the actual SSH

---

    $ make ssh[:{service-name}]

When you are ready to SSH, you can just go

    $ make ssh


Or for one of your services

    $ make ssh:service-A


If you have provided an `ipv4_address` output it will use that, if not you will
be prompted to provide the IP address. As well as provide the login for the
current SSH session you are about to begin.

&nbsp;

---

## TODO

---

- [ ] Add a `tf:make:all` target to run `tf:make` on all.
- [ ] Multiple service example
- [ ] Clean up some `define` vs shell function definitions
- [ ] Did I cover everything I should have in the README?

[splash]: https://s3.amazonaws.com/assets.github.com/splash-.tf.makefile.svg
[tfmakefile]: .tf.makefile
