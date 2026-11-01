# Multi-region lab runbook

Build Sydney and London with the lab profile, watch a release reach one region and then the
other, and tear everything down. About 2-2.5 hours end to end, roughly US$4-5 in total.

Everything that costs money is in steps 2-4 and is removed in step 7. Run
`scripts/aws-inventory.sh` before and after.

| Step | Sydney and London | Time |
|---|---|---|
| 0. Foundation | `make foundation-up` from your laptop (bucket, CI roles, ECR in both regions) | 1 min |
| 1. Images | GitLab pipelines push to ECR Sydney; ECR copies to London | 5 min |
| 2. Build | GitHub Actions `apply`: both regions in parallel | 50-70 min |
| 3. Nothing to hand off | gitops already names the secrets and bucket | 0 min |
| 4. Argo CD | Already installed by step 2; it deploys the rest | 10 min |
| 5. Look around | Two ALB URLs, two Argo CDs | as long as you like |
| 6. Region-by-region release | Merge for Sydney, then promote to London | 15 min |
| 7. Teardown | GitHub Actions `destroy`: drain, then 40 -> 30 -> 20 -> 10 | 20-25 min |

## 0. Foundation (laptop, costs cents)

    make foundation-up      # shows the plan, type yes

Skip it if it's already up (`scripts/aws-inventory.sh` shows the bucket and CI roles).

## 1. Images (no AWS infrastructure)

Run the `main` pipelines in GitLab `backend` and `frontend` (Build > Pipelines > Run pipeline).
Each pushes `<short sha>` to ECR and opens a release MR in `gitops`. Don't merge those yet.

    aws ecr list-images --region eu-west-2 --repository-name backend   # replicated copy

## 2. Build with GitHub Actions

GitHub > `platform-infra` > Actions > **apply** > **Run workflow** (branch `main`).

1. **plan** (read-only role): plans every stack. Before the first build, the stacks that
   depend on others show "Skipped: needs 10-network". The run summary lists every result.
2. **apply-region** pauses: **Review deployments** > tick `production` > **Approve**.
   **Two jobs start, one per region, in parallel**. Each runs 10-network -> 20-eks (~15 min) -> 30-data -> 40-argocd.
   Sydney's 30-data creates the primary database (~15 min, Multi-AZ). London's job waits for
   it, then creates the cross-region read replica (~20-30 min).

Same code, different tfvars, one job per region: that's the multi-region pattern on the
infra side. Open the two jobs side by side to watch the regions build independently.

## 3. Nothing to hand off

The gitops values already name everything by fixed names: the secrets
`prod/webapp/database` (username, password; Secrets Manager replicates it from Sydney to
London) and `prod/webapp/database-endpoint` (each region's own host), and the bucket
`prod-<region>-webapp-media-<account id>`. External Secrets picks them up as soon as 30-data
has created them.

## 4. Argo CD

Step 2's last job, 40-argocd, installed Argo CD and one root Application per cluster,
pointing at that region's folder. From there Argo CD deploys everything: projects, add-ons,
then the web app. To look at it from your laptop (your IAM user is a cluster admin):

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
   The migration has already reached London's database through replication.
2. Check Sydney through its ALB URL. Create a note there; it shows up in London's UI too.
3. Promote, at least 30 minutes after the Sydney release merged: in gitops, open the latest
   `main` pipeline and press **promote-eu-west-2**. The job refuses to run sooner. It opens the
   promotion MR; merge it. London deploys the same images, pulled from London's ECR, and
   skips the migration Job (its database is read-only).
4. Try a rollback in one region: revert the London MR and watch only London go back.

## 7. Teardown with GitHub Actions

GitHub > Actions > **destroy** > **Run workflow**: regions `both`, type `destroy`, run, then
approve `production`. One job per region:

1. `drain-cluster.sh`: delete the web app so the AWS Load Balancer Controller removes the ALB
2. destroy 40-argocd, switch off the database's deletion protection, destroy 30-data (Sydney
   waits for London's replica to be gone first), 20-eks, 10-network
3. list what's left in that region (should be only ECR)

Why drain first: the ALB is created by a Kubernetes controller, not by Terraform. Destroy the
cluster first and nothing deletes the ALB, and the VPC can't be destroyed with it inside.
Prometheus' 50 GB EBS volume is the same story: it belongs to a PersistentVolumeClaim, so the
drain deletes the claim while the cluster can still delete the volume.

From a laptop instead: see Destroy in the README. Afterwards `scripts/aws-inventory.sh` shows
what exists.

Finished with the project for now? Take the foundation down too (deletes the images):

    make foundation-down    # refuses if a region still has resources
    scripts/aws-inventory.sh   # everything empty

## What to say about it in an interview

- Each region is a cell: its own VPC, EKS, RDS and Argo CD, built from the same Terraform
  with different variables. The one runtime link is the database: London's RDS is a
  cross-region read replica of Sydney's, a warm standby promoted by a runbook
  (`docs/database-failover.md`), not automatically.
- Inside a region: NAT gateway per AZ, Multi-AZ RDS with deletion protection, ECR/STS
  interface endpoints and an S3 gateway endpoint so image pulls stay in the VPC.
- One image build serves every region through ECR replication; each cluster pulls locally.
- A release is a Git change to one region's folder. Promotion is a second change. Rollback is
  a revert, per region.
- Things that live outside Terraform (ALBs from Ingresses, EBS volumes from PVCs) need an
  explicit teardown step.
