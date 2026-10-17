# Multi-region lab runbook

Build Sydney and London with the lab profile, watch a release reach one region and then the
other, and tear everything down. About 2 hours end to end, roughly US$2-3 in total.

Everything that costs money is in steps 2-4 and is removed in step 7. Run
`scripts/aws-inventory.sh` before and after.

| Step | Sydney and London | Time |
|---|---|---|
| 1. Images | GitLab pipelines push to ECR Sydney; ECR copies to London | 5 min |
| 2. Network + EKS + data | Terraform, both regions in parallel | 25-30 min |
| 3. Hand-off | Database outputs into the gitops repo | 2 min |
| 4. Argo CD | Terraform installs it; it deploys the rest | 10 min |
| 5. Look around | Two ALB URLs, two Argo CDs | as long as you like |
| 6. Region-by-region release | Merge for Sydney, then promote to London | 15 min |
| 7. Teardown | Drain, then destroy 40 -> 30 -> 20 -> 10 | 20-25 min |

## 1. Images (no AWS infrastructure)

Run the `main` pipelines in GitLab `backend` and `frontend` (Build > Pipelines > Run pipeline).
Each pushes `<short sha>` to ECR and opens a release MR in `gitops`. Don't merge those yet.

    aws ecr list-images --region eu-west-2 --repository-name backend   # replicated copy

## 2. Network, EKS, data (both regions at once)

Two terminals, one per region. Each `apply` shows the plan and asks for `yes`.

    # terminal 1                                   # terminal 2
    scripts/tf.sh apply 10-network ap-southeast-2  scripts/tf.sh apply 10-network eu-west-2
    scripts/tf.sh apply 20-eks ap-southeast-2      scripts/tf.sh apply 20-eks eu-west-2      # ~15 min
    scripts/tf.sh apply 30-data ap-southeast-2     scripts/tf.sh apply 30-data eu-west-2     # ~10 min

Same code, different tfvars: that's the whole multi-region pattern on the infra side.

## 3. Hand-off to gitops

The database host, RDS secret and media bucket only exist now. Write them into gitops:

    scripts/gitops-handoff.sh ap-southeast-2
    scripts/gitops-handoff.sh eu-west-2
    cd ../gitops && git commit -am "Hand-off: lab database outputs" && git push

## 4. Argo CD

    scripts/tf.sh apply 40-argocd ap-southeast-2   scripts/tf.sh apply 40-argocd eu-west-2

Terraform installs Argo CD and one root Application per cluster, pointing at that region's
folder. From here Argo CD deploys everything: projects, add-ons, then the web app.

    aws eks update-kubeconfig --region ap-southeast-2 --name prod-ap-southeast-2 --alias syd
    aws eks update-kubeconfig --region eu-west-2 --name prod-eu-west-2 --alias lon
    kubectl --context syd -n argocd get applications
    kubectl --context lon -n argocd get applications

The backend can't start yet: its image tag is still `pending-first-build`. That's expected.

## 5. Look around

    kubectl --context syd -n webapp-prod get ingress   # ALB DNS name -> open in a browser
    kubectl --context syd -n argocd port-forward svc/argocd-server 8080:80
    kubectl --context syd -n argocd get secret argocd-initial-admin-secret \
      -o jsonpath='{.data.password}' | base64 -d

## 6. Region-by-region release

1. Merge the two release MRs in `gitops` (backend and frontend). They change only
   `envs/prod/ap-southeast-2/`. Sydney deploys: migration Job, then the rollout. London is
   untouched; `kubectl --context lon -n webapp-prod get pods` still shows nothing new.
2. Check Sydney through its ALB URL.
3. Promote:

       cd ../gitops && git checkout -b promote-london
       scripts/promote.sh ap-southeast-2 eu-west-2
       git commit -am "Promote to eu-west-2" && git push -u origin promote-london

   Open and merge the MR. London deploys the same images, pulled from London's ECR.
4. Try a rollback in one region: revert the London MR and watch only London go back.

## 7. Teardown (both regions, in this order)

    scripts/drain-cluster.sh ap-southeast-2        scripts/drain-cluster.sh eu-west-2
    scripts/tf.sh destroy 40-argocd ap-southeast-2 scripts/tf.sh destroy 40-argocd eu-west-2
    scripts/tf.sh destroy 30-data ap-southeast-2   scripts/tf.sh destroy 30-data eu-west-2
    scripts/tf.sh destroy 20-eks ap-southeast-2    scripts/tf.sh destroy 20-eks eu-west-2
    scripts/tf.sh destroy 10-network ap-southeast-2 scripts/tf.sh destroy 10-network eu-west-2
    scripts/aws-inventory.sh

Why drain first: the ALB is created by a Kubernetes controller, not by Terraform. Destroy the
cluster first and nothing deletes the ALB, and the VPC can't be destroyed with it inside.

Then reset the hand-off values in gitops (`git revert` the hand-off commit) so the next lab
starts clean.

## What to say about it in an interview

- Each region is a cell: its own VPC, EKS, RDS and Argo CD, built from the same Terraform
  with different variables. Nothing at runtime crosses regions.
- One image build serves every region through ECR replication; each cluster pulls locally.
- A release is a Git change to one region's folder. Promotion is a second change. Rollback is
  a revert, per region.
- Things that live outside Terraform (ALBs from Ingresses, EBS volumes from PVCs) need an
  explicit teardown step.
