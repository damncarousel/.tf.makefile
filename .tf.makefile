# _Path tries to nomalize the path given the module we want (first arg)
# regardless of whether we are outside or in the given module
#
# Example:
#
#	pwd => /path/to/infra
#	$(call _Path,nginx)
#	=> /path/to/infra/nginx
#
#	pwd => /path/to/infra/nginx
#	$(call _Path,nginx)
#	=> /path/to/infra/nginx
#
# This allows us to call our commands with namespaces in the root or within the
# module itself.
#
# NOTE this generall assumes that your terraform module structures are only 1
# directory deep
#
#	/path/to/infra
#		./nginx
#		./app
#
# FIXME will not path properly if the module we actually want is the same name
# as the parent dir we are calling this function from
#
#	/path/to/app
#		./nginx
#		./app
#
#	pwd => /path/to/app
#	$(call _Path,app)
#	=> /path/to/app
#
#	In this case we want /path/to/app/app
#
# As an aside, my echo | sed method probably not the best way to do this...
#
# @param ( 1 ) name of the module/directory
define _Path =
$(shell echo "$$(pwd)/$(1)" | sed -e 's#/$(1)/$(1)$$#/$(1)#ig' | sed -e 's#/\.$$##ig')
endef

# _Basename returns the basename on pwd
define _Basename
$(shell echo "$$(basename $$(pwd))")
endef

# VarfilesValue returns the <module>_VAR_FILES= defined in the module's
# .makefile allowing us to predefine our variable file reference and use
# those when we # call `terraform plan`
define VarfilesValue
$(value $(shell echo "$(call _Basename)_var_files" | tr 'a-z' 'A-Z'))
endef

# Mkdir is `mkdir`
#
# @param ( 1 ) path of the directory to mkdir
# @param ( 2 ) mkdir flags
# @api public
define Mkdir =
mkdir $(2) $(1)
endef

# Log is just an echo
#
# @param ( 1 ) string to echo
# @param ( 2 ) echo flags
# @api public
define Log =
echo $(2) $(1)
endef


# Terraform commands
#

# tf:init is terraform init
tf\:init:
	@terraform init
.PHONY: tf\:init

# %/tf:init calls tf:init from the given module
#
#	nginx/tf:init
#
%/tf\:init:
	@$(MAKE) -s -C $(call _Path,$*) tf:init
.PHONY: %/tf\:init

# tf:reset removes the .terraform directory
tf\:reset:
	@rm -rf .terraform
.PHONY: tf\:reset

# %/tf:reset calls tf:reset from the given module
%/tf\:reset:
	@$(MAKE) -s -C $(call _Path,$*) tf:reset
.PHONY: %/tf\:reset

# tf:plan calls terraform plan and outputs as 'plan'
tf\:plan:
	@terraform plan $(call VarfilesValue) -out=plan
.PHONY: tf\:plan

# %/tf:plan calls tf:plan from the given module
%/tf\:plan:
	@$(MAKE) -s -C $(call _Path,$*) tf:plan
.PHONY: %/tf\:plan

# tf:clean removes the created 'plan'
tf\:clean:
	@rm -f plan
.PHONY: tf\:clean

# %/tf:clean calls tf:clean from the given module
%/tf\:clean:
	@$(MAKE) -s -C $(call _Path,$*) tf:clean
.PHONY: %/tf\:clean

# tf:apply calls terraform apply on the plan
#
# NOTE if ./plan does not exist it will run tf:plan
#
tf\:apply:
	@if [ ! -f ./plan ]; then \
		$(MAKE) -s tf:plan; \
	fi
	@terraform apply plan
.PHONY: tf\:apply

# %/tf:apply calls tf:apply from the given module
%/tf\:apply:
	@if [ ! -f "$*/plan" ]; then \
		$(MAKE) -s $*/tf:plan; \
	fi
	@$(MAKE) -s -C $(call _Path,$*) tf:apply
.PHONY: %/tf\:apply

# tf:apply! (note !) calls a tf:clean before tf:apply, this ensures plan is
# always run
tf\:apply!: 
	@$(MAKE) -s tf:clean
	@$(MAKE) -s tf:apply
.PHONY: tf\:apply! 

# %/tf:apply! calls tf:apply! from the given module
%/tf\:apply!:
	@$(MAKE) -s $*/tf:clean
	@$(MAKE) -s $*/tf:apply
.PHONY: %/tf\:apply!

# tf:__destroy__ calls terraform destroy
#
# NOTE the reason we name it this way is because we want to make calling this a
# PITA as it will destroy your stuff. This makes it "private", sort of...
#
# Also if you want to force confirmation of a destroy for a large teardown
# process of a number of terraform modules, you have to directly use this.
#
#	echo Yes | make tf:__destroy__
#
tf\:__destroy__:
	@terraform destroy $(call VarfilesValue)
.PHONY: tf\:__destroy__

# %/tf:__destroy__ calls tf:__destroy__ from the given module
%/tf\:__destroy__:
	@$(MAKE) -s -C $(call _Path,$*) tf:__destroy__
.PHONY: %/tf\:__destroy__

# tf:destroy calls the tf:__destroy__ but must be confirmed by a key. The key
# is generated automatically on each call
#
# Thank you! https://gist.github.com/earthgecko/3089509
#
tf\:destroy:
	@$(eval NAME=$(call _Basename))
	@key=$$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1); \
		echo "To destroy '$(NAME)', you must verify your key."; \
		echo "Your current key is: $$key\n"; \
		read -p "Verify: " __key; \
		if [ "$$key" != "$$__key" ]; then \
			echo; \
			echo "The key you provided was invalid"; \
			echo; \
			exit 1; \
		fi
	@echo
	@$(MAKE) -s tf:__destroy__
.PHONY: tf\:destroy

# %/tf:destroy calls tf:destroy from the given module
%/tf\:destroy:
	@$(MAKE) -s -C $(call _Path,$*) tf:destroy
.PHONY: %/tf\:destroy


# SSH commands
#

# hasSshDir checks for an .ssh directory
hasSshDir:
	@if [ ! -d .ssh ]; then \
		echo "$(call _Basename) ($$(pwd)) does not contain an .ssh folder"; \
		echo "To support SSH please create an .ssh folder in $$(pwd)"; \
		echo; \
		exit 1; \
	fi
.PHONY: hasSshDir

# mkdir:.ssh creates a .ssh directory
#
# NOTE we add .gitkeep to repo the directory, but we don't want to repo the
# keys
#
# sample of .gitignore to do this,
#
#	.ssh/**/*
#	!.ssh/.gitkeep
#
mkdir\:.ssh:
	@mkdir -p .ssh
	@touch .ssh/.gitkeep
.PHONY: mkdir\:.ssh

# %/mkdir:.ssh calls mkdir:.ssh from the given module
%/mkdir\:.ssh:
	@$(MAKE) -s -C $(call _Path,$*) mkdir:.ssh
.PHONY: %/mkdir\:.ssh

# ssh-keygen helps generate an ssh key
#
# NOTE you must a .ssh directory to designate that the current module supports
# or needs ssh keys
#
ssh-keygen:
	@$(MAKE) -s hasSshDir
	@ssh-keygen -t rsa -b 4096 -f "$$(pwd)/.ssh/id_rsa"
	@sudo chmod -R 600 $$(pwd)/.ssh/*
.PHONY: ssh-keygen

# %/ssh-keygen calls ssh-keygen from the given module
%/ssh-keygen:
	@$(MAKE) --no-print-directory -C $(call _Path,$*) ssh-keygen
.PHONY: %/ssh-keygen

# rm:.ssh removes the contents of the .ssh folder
rm\:.ssh:
	@$(MAKE) -s hasSshDir
	@rm -f .ssh/*
.PHONY: rm\:.ssh

# %/rm:.ssh calls rm:.ssh from the given module
%/rm\:.ssh:
	@$(MAKE) --no-print-directory -C $(call _Path,$*) rm:.ssh
.PHONY: %/rm\:.ssh

# tf:output:% runs terraform output on the given variable name
#
# NOTE this is generally for debugging and not readily used
#
tf\:output\:%:
	@echo $(call TerraformOutput,$*)
.PHONY: tf\:output\:%

# TerraformOutput runs a terraform output on a given variable name
#
# NOTE stder > /dev/null
#
define TerraformOutput =
$(shell terraform output $(1) 2>/dev/null)
endef

# ssh launches an ssh session using the .ssh/id_rsa generated from
# `make ssh-keygen`
#
ssh:
	@$(MAKE) -s hasSshDir
	@$(eval IP=$(call TerraformOutput,'ipv4_address'))
	@$(eval NAME=$(call _Basename))
	@echo "SSH $(NAME) -\n"
	@echo "What is the IP[V4] address of the $(NAME) instance?"
	@if [ -z "$(IP)" ]; then \
		read -p "IP[V4]: " ip; \
		ip="$$ip" $(MAKE) -s _ssh; \
	else \
		echo "'ipv4_address' output found, using: $(IP)"; \
		ip="$(IP)" $(MAKE) -s _ssh; \
	fi
.PHONY: ssh

# _ssh is an extension of ssh, this is not called directly, because of our read
# -p scoping
_ssh:
	@echo; \
		echo "Who do you want to SSH in as?"; \
		read -p "Username: " username; \
		echo; \
		echo "Thank you... one moment as we SSH $$username@$$ip"; \
		echo; \
		ssh -i "$$(pwd)/.ssh/id_rsa" $$username@$$ip
.PHONY: _ssh

# ssh:% calls ssh for the given module
ssh\:%:
	@$(MAKE) -s -C $(call _Path,$*) ssh
.PHONY: ssh\:%


# Bootstrapping commands
#

# tf:make runs a number of commands to set up your terraforms for deployment
tf\:make:
	@$(MAKE) -s cp:tfvars
	@$(MAKE) -s register:varfiles
	@$(MAKE) -s tf:init
.PHONY: tf\:make

# %/tf:make calls tf:make from the given module
%/tf\:make:
	@$(MAKE) -s -C $(call _Path,$*) tf:make
	@$(MAKE) -s $*/ln:provider.tf
.PHONY: %/tf\:make

# tf:make! calls `tf:make` but removes the copied tfvars first
tf\:make!:
	@$(MAKE) -s rm:tfvars
	@$(MAKE) -s tf:make
.PHONY: tf\:make!

# %/tf:make calls tf:make! from the given module
%/tf\:make!:
	@$(MAKE) -s -C $(call _Path,$*) tf:make!
.PHONY: %/tf\:make!

# register:varfiles writes the {service}_VAR_FILES variable to file
register\:varfiles:
	@$(call RegisterVarfiles,$(call _Basename),._tf.makefile)
.PHONY: register\:varfiles

# %/register:varfiles calls register:varfiles for the given module
%/register\:varfiles:
	@$(MAKE) -s -C $(call _Path,$*) register:varfiles
.PHONY: %/register\:varfiles

# ln:provider.tf symlinks the parent's provider file to the current dir
#
# NOTE this will remove the provider before linking
ln\:provider.tf:
	@$(call RemoveProvider)
	@$(call LinkProvider)
.PHONY: ln\:provider.tf

# RemoveProvider removes the provider.tf file
#
# @api private
define RemoveProvider
rm -f provider.tf
endef

# LinkProvider symlinks provider.tf to a parent (one node up) provider.tf
#
# @api private
define LinkProvider
ln -s ../provider.tf provider.tf
endef

# %/ln:provider.tf calls ln\:provider.tf from the given module
%/ln\:provider.tf:
	@$(MAKE) -s -C $(call _Path,$*) ln:provider.tf
.PHONY: %/ln\:provider.tf

# cp:tfvars copies the tfvars file from .templates
cp\:tfvars:
	@$(call CopyTfvars)
.PHONY: cp\:tfvars

# CopyTfvars copies the tfvars files from the .templates directory, renaming
# then with a dot (.) prefix
#
# @api private
define CopyTfvars
for file in ./.templates/*.tfvars; do \
	cp -n "$$file" .$$(basename "$$file"); \
done
endef

# %/cp:tfvars calls cp:.fvars from the given module
%/cp\:tfvars:
	$(MAKE) -s -C $(call _Path,$*) cp:tfvars
.PHONY: %/cp\:tfvars

# RemoveCopiedTfvars removes the copied tfvars files based on what exists in
# the .templates directory
#
# @api private
define RemoveCopiedTfvars
for file in ./.templates/*.tfvars; do \
	rm -f .$$(basename "$$file"); \
done
endef

# rm:tfvars removes copied tfvars files
rm\:tfvars:
	@$(call RemoveCopiedTfvars)
.PHONY: rm\:tfvars

# %/rm:tfvars calls tf:vars from the given module
%/rm\:tfvars:
	@$(MAKE) -s -C $(call _Path,$*) rm:tfvars
.PHONY: %/rm\:tfvars


# tf:new creates the basic terraform structure for our use case as well as
# including/bootstrapping makefiles and targets 
#
#	current/
#		.templates/
#			variables.tfvars
#		._tf.makefile
#		Makefile
#		variables.tf
#
# If the diretory is a "root" directory, additional files and structures will
# be created along with the above
#
#	root/
#		.templates/
#			provider.tfvars
#			variables.tfvars
#		._tf.makefile
#		.tf.makefile (this is this file, won't be touched)
#		Makefile
#		provider.tf
#		variables.tf
#
# TODO do any of these need to be individual targets that would would call
# again? Similar to how tf:make is defined?
tf\:new:
	@$(eval current=$(call _Basename))
	@$(call Log,"Creating $(current)... ",-n)
	@$(call CreateDir)
	@$(call RegisterMakefiles,$(current))
	@$(call WriteTargets,$(current))
	@$(call RegisterVarfiles,$(current),._tf.makefile)
	@$(call CheckMulti)
	@$(call Log,"complete")
.PHONY: tf\:new

# CreateDir creates the core directory structure and files
#
# @api private
define CreateDir
mkdir -p .templates
touch .templates/variables.tfvars
touch ._tf.makefile
touch Makefile
touch variables.tf
\
$(fnIsRoot); \
\
if [ "`IsRoot`" = "1" ]; then \
	touch provider.tf; \
	touch .templates/provider.tfvars; \
fi
endef

# RegisterMakefiles includes the makefile dependencies 
#
# @param ( 1 ) the subdirectory name
# @api private
define RegisterMakefiles =
$(fnIsRoot);       \
$(fnInsertBefore); \
\
if [ ! "`IsRoot`" = "1" ]; then \
	echo include ../.tf.makefile >> Makefile; \
	echo "\n#eof" >> Makefile; \
		InsertBefore 'include\s*\.tf\.makefile' "include $(1)/._tf.makefile" ../Makefile; \
fi; \
InsertBefore 'include\s*.*\.tf\.makefile' 'include ._tf.makefile' Makefile
endef

# WriteTargets writes the a default set of make targets
#
# @param ( 1 ) name of the module
# @api private
define WriteTargets =
$(fnInsertBefore); InsertBefore 'include\s*\._tf\.makefile' " \
# tf:targets\\
\\
plan:\\
\t@\$$(MAKE) -s $(1)/tf:\$$@;\\
.PHONY: plan\\
\\
apply:\\
\t@\$$(MAKE) -s $(1)/tf:\$$@;\\
.PHONY: apply\\
\\
apply!:\\
\t@\$$(MAKE) -s $(1)/tf:\$$@;\\
.PHONY: apply!\\
\\
destroy:\\
\t@\$$(MAKE) -s $(1)/tf:\$$@;\\
.PHONY: destroy\\
\\
# /tf:targets\\
" Makefile

echo "#eof" >> ._tf.makefile

$(fnInsertBefore); InsertBefore '#eof' " \
# tf:targets\\
\\
$(1):\\
\t@\$$(MAKE) -s \$$@/tf:apply!\\
.PHONY: $(1)\\
\\
# /tf:targets\\
" ._tf.makefile
endef

# RegisterVarfiles sets the var files as a var
#
# NOTE this is all in reverse to use the InsertAtTop func
#
# @param ( 1 ) name of the module
# @param ( 2 ) the file to use (and rewrite to)
# @api private
define RegisterVarfiles =
$(fnRegexReplace); \
$(fnInsertAtTop);  \
$(fnGetVarfiles);  \
$(fnAdvReplace);   \
\
if [ -f "$(2)" ]; then \
	AdvReplace '#\stf:varfiles.*#\s\/tf:varfiles\(\n*\)' '' $(2) g ':a;N;$$!ba;'; \
	InsertAtTop "\n\n# \/tf:varfiles\n\n" $(2); \
	InsertAtTop "`GetVarfiles | RegexReplace '\s\\\\\\\\$$' ''`" $(2); \
	InsertAtTop "`echo '$(1)_var_files= \\\\\' | tr 'a-z' 'A-Z'`" $(2); \
	InsertAtTop "# tf:varfiles\n\n" $(2); \
fi
endef

# CheckMulti looks for the MULTI=true var and refactors the changes of tf:new
# to turn the current setup for submodules
define CheckMulti
$(fnAdvReplace); \
\
if [ "$$MULTI" = "true" ]; then \
	rm ._tf.makefile; \
	AdvReplace 'include\s\._tf\.makefile' '' Makefile g; \
	AdvReplace '#\stf:targets.*#\s\/tf:targets' '' Makefile g ':a;N;$$!ba;'; \
fi
endef

# %/tf:new calls tf:new on a newly created subdirectory
%/tf\:new:
	@$(call Mkdir,$*)
	@cd $(call _Path,$*); make -s -f ../.tf.makefile tf:new
.PHONY: %/tf\:new

# tf:rename provides a utility to rename generated targets if, for example,
# your repo was checked out under a different name than the original
tf\:rename:
	@$(eval current=$(call _Basename))
	@$(call ClearTargets,Makefile)
	@$(call ClearTargets,._tf.makefile)
	@$(call WriteTargets,$(current))
.PHONY: tf\:rename

# ClearTargets clears the tf:targets block content for a rewrite of
# WriteTargets
#
# @param ( 1 ) the file to use (and rewrite to)
# @api private
define ClearTargets
$(fnAdvReplace); \
\
AdvReplace '#\stf:targets.*#\s\/tf:targets\(\n*\)' '' $(1) g ':a;N;$$!ba;'
endef

# %/tf:rename calls tf:rename on the given module
#
# TODO this needs to also repath the include for the modules ._tf.makefile
%/tf\:rename:
	@$(MAKE) -s -C $(call _Path,$*) tf:rename
.PHONY: %/tf\:rename

# .tf.makefile:init makes the main Makefile and includes this file
#
# Because from scratch you won't have this included in your Makefile, use the
# `-f` to call the target
#
#	make -f .tf.makefile .tf.makefile:init
#
.tf.makefile\:init:
	@$(call Log,"Setting up .tf.makefile...",-n)
	@$(call CreateMakefile)
	@$(call Log,"complete")
.PHONY: .tf.makefile\:init

# CreateMakefile makes the main Makefile and includes this file
#
# @api private
define CreateMakefile
echo > Makefile
echo 'include .tf.makefile' >> Makefile
echo >> Makefile
echo '#eof' >> Makefile
echo >> Makefile
endef


# shell funcs
#

# TODO can we do something like this? 
# fnMustModule=MustModule() {
# 	if [ ! -f provider.tf ]; then \
# 		exec $$1; \
# 	fi
# }

# AdvReplace is a sed find and replace
#
# @param ( 1 ) regex pattern
# @param ( 2 ) text to replace with
# @param ( 3 ) the file to use (rewrite to)
# @param ( 4 ) regex flags
# @param ( 5 ) sed command
fnAdvReplace=AdvReplace() { \
	sed -i "$$5"'s/'"$$1"'/'"$$2"'/'"$$4" $$3; \
}

# RegexReplace is a function for sed -e replace
#
# TODO can this be replaced with AdvReplace?
#
# @param ( 1 ) text to find
# @param ( 2 ) text to replace found text
# @return (String)
# @api private
fnRegexReplace=RegexReplace() { \
	sed -e "s/$$1/$$2/g"; \
}

# InsertAtTop inserts text at the top of a file
#
# TODO can this be replaced with AdvReplace?
#
# @param ( 1 ) text to insert
# @param ( 2 ) the file to use (and rewrite to)
# @api private
fnInsertAtTop=InsertAtTop() { \
	sed -i '1s/^/'"$$1"'/' $$2; \
}

# InsertBefore is a function that wraps sed to insert before a matched phrase
# in the given file
#
# @param ( 1 ) the phrase to match (Regex)
# @param ( 2 ) the text to insert
# @param ( 3 ) the file to use (and rewrite to)
# @api private
fnInsertBefore=InsertBefore() { \
	sed -i -e "/$$1/{i$$2" -e ':a;n;ba}' $$3; \
}

# GetVarfiles returns a newline \ delimeted list of the (dot) tfvar files
#
# NOTE if the varfiles we are getting is for a module it will add any var
# files from it's parent as well
#
# @return (String)
# @api private
fnGetVarfiles=GetVarfiles() { \
	$(fnIsRoot); \
	\
	templates_dir="./.templates/*.tfvars"; \
	if [ ! "`IsRoot`" = "1" ]; then \
		templates_dir="./.templates/*.tfvars ../.templates/*.tfvars"; \
	fi; \
	for f in $$templates_dir; do \
		echo -n "\\\n\t-var-file=$$(dirname $$(dirname $$f))\/.$$(basename $$f) \\\\\\"; \
	done \
}

# IsRoot assumes that if a .git folder is present or the var TF_ROOT=true is
# given then the target being run is run within the "root" directory
#
# NOTE What makes a "root" directory exactly?...
#	- It has a `.git` directory meaning it's the repo root
#	- Or, it has a `provider.tf` (not a symlink)
#	    This will have various mileage depending on your setup, but we assume a
#	    "normal" (my normal...)
#	- Or, you define a `TF_ROOT=true` var when calling a command that checks
#	  for `IsRoot`
#
# @return (Number) 1 or null
# @api private
fnIsRoot=IsRoot() { \
	[ -d ".git" ] || ([ -f "provider.tf" ] && [ ! -L "provider.tf" ]) || [ "$$TF_ROOT" = 'true' ] && echo 1; \
}
