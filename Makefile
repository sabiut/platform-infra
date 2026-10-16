REGIONS := ap-southeast-2 eu-west-2
STACKS  := 10-network 20-eks 30-data 40-argocd

.PHONY: fmt validate plan-only

fmt:
	terraform fmt -recursive

validate:
	@for d in bootstrap global $(addprefix stacks/,$(STACKS)); do \
	  (cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate -no-color) || exit 1; \
	done

# Plan everything before anything exists. Nothing is created.
plan-only:
	scripts/tf.sh plan bootstrap
	PLAN_ONLY=1 scripts/tf.sh plan global
	@for r in $(REGIONS); do for s in $(STACKS); do \
	  PLAN_ONLY=1 scripts/tf.sh plan $$s $$r || exit 1; \
	done; done
