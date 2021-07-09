SCMVERSION := $(shell git describe --tags --dirty=+ --always 2>/dev/null || \
		echo "UNKNOWN")
SCMBRANCH := $(shell (git branch 2> /dev/null || echo '* UNKNOWN') | \
		awk '/^\* / {print $$2;}')
DATESTR := $(shell date)

% : %.lua
	@sed -e "s;%%%VERSION%%%;$(SCMBRANCH)/$(SCMVERSION);g" -e "s;%%%DATE%%%;$(DATESTR);g" $<
