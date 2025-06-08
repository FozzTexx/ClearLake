IMAGE=clearlake
FZREPO=https://github.com/FozzTexx

MINOR_V3=0
VERSION_V3=v3.$(MINOR_V3)

MINOR_V2=0
VERSION_V2=v2.$(MINOR_V2)

MINOR_V1=0
VERSION_V1=v1.$(MINOR_V1)

-include ClearLake-deps.make
FPCLDEPS=$(addprefix ../,$(CLDEPS))

define bundle-recipe =
	$(eval BUNDLE=$1)
	$(eval REPO=$2)
	$(eval BRANCH=$3)
	$(eval PKG=$(basename $(BUNDLE)))
	BRANCH=$(BRANCH) \
	&& CURDIR=$${PWD} \
	&& TMP=/tmp/bundle.$$$$ \
	&& mkdir $${TMP} \
	&& cd $${TMP} \
	&& git -c http.sslVerify=false clone $${BRANCH:+-b $${BRANCH}} $(REPO) $(PKG) \
	&& cd $(PKG) \
	&& git bundle create ../$@ --all \
	&& cd $${CURDIR} \
	&& mv $${TMP}/$@ . \
	&& rm -rf $${TMP}
endef

v3: Dockerfile-v3 install-clearlake.sh		\
	ClearLake-v3.tar hoedown.bundle fozzlib.bundle	\
	piclib.bundle fzlocal.bundle
	env BUILDKIT_PROGRESS=plain \
	  docker buildx build $(REBUILDFLAGS) -f $< \
	    --build-arg CL_VERS_MAJOR=$@ \
	    --build-arg http_proxy=$(http_proxy) \
	    --build-arg https_proxy=$(https_proxy) \
	    --build-arg no_proxy=$(no_proxy) \
	    --rm -t $(IMAGE):$(VERSION_V3) .

v2: Dockerfile-v2 install-clearlake.sh		\
	ClearLake-v2.bundle hoedown.bundle fozzlib.bundle	\
	piclib.bundle fzlocal.bundle
	env BUILDKIT_PROGRESS=plain \
	  docker buildx build $(REBUILDFLAGS) -f $< \
	    --build-arg CL_VERS_MAJOR=$@ \
	    --build-arg http_proxy=$(http_proxy) \
	    --build-arg https_proxy=$(https_proxy) \
	    --build-arg no_proxy=$(no_proxy) \
	    --rm -t $(IMAGE):$(VERSION_V2) .

v1: Dockerfile-v1 install-clearlake.sh ClearLake-v1.bundle		\
	OnionPatch.bundle hoedown.bundle fozzlib.bundle piclib.bundle	\
	fzlocal.bundle
	env BUILDKIT_PROGRESS=plain \
	  docker buildx build $(REBUILDFLAGS) -f $< \
	    --build-arg CL_VERS_MAJOR=$@ \
	    --build-arg http_proxy=$(http_proxy) \
	    --build-arg https_proxy=$(https_proxy) \
	    --build-arg no_proxy=$(no_proxy) \
	    --rm -t $(IMAGE):$(VERSION_V1) .


site.tar: $(FP_SITE_FILES)
	tar -cf $@ -C .. $(SITE_FILES)

ClearLake-v3.tar: ClearLake-deps.make $(FPCLDEPS)
	tar -cf $@ -C .. --transform 's,^,ClearLake/,' $(CLDEPS)

ClearLake-v3.bundle: ClearLake-deps.make $(FPCLDEPS)
	$(call bundle-recipe, $@, $(shell realpath ..), release/v3.x)

ClearLake-v2.bundle:
	$(call bundle-recipe, $@, $(shell realpath ..), main)
#	$(call bundle-recipe, $@, $(shell realpath ..), release/v2.x)

ClearLake-v1.bundle:
	$(call bundle-recipe, $@, $(shell realpath ..), release/v1.x)

fozzlib.bundle:
	$(call bundle-recipe, $@, $(FZREPO)/$(basename $@).git)

piclib.bundle:
	$(call bundle-recipe, $@, $(FZREPO)/$(basename $@).git)

OnionPatch.bundle:
	$(call bundle-recipe, $@, git.fozztexx.com:source/$(basename $@))

fzlocal.bundle:
	$(call bundle-recipe, $@, git.fozztexx.com:/srv/git/$(basename $@).git)

hoedown.bundle:
	$(call bundle-recipe, $@, https://github.com/$(basename $@)/$(basename $@).git)

ClearLake-deps.make:
	(echo 'define CLDEPS ' \
	  ; git ls-tree --full-tree -r --name-only --full-name HEAD | sort \
	 | sed -e '/^\(docker\|docs\)[/]/d ; /^[.]/d' \
	       -e 's/$$/ \\/ ; $$s/.$$//' \
          ; echo endef ) > $@
