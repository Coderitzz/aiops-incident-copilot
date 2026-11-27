# Jenkins setup (one-time, about 10 minutes)

Ansible installs Jenkins, Docker, AWS CLI, kubectl, Helm and Trivy on the `ci` host and gives
the `jenkins` user a kubeconfig for the k3s cluster. Jenkins itself is configured in the UI.

1. Install everything:

       make ansible-platform

2. Open Jenkins through an SSH tunnel (it has no public IP):

       make jenkins-password      # prints the unlock password
       make jenkins-tunnel        # leave running, then open http://localhost:8080

3. Unlock it, choose **Install suggested plugins**, create an admin user.

4. **New Item** -> name `aiops` -> **Pipeline** -> OK.
   - Definition: **Pipeline script from SCM**, SCM: **Git**
   - Repository URL: your GitHub repo. For a private repo add a credential
     (Kind: Username with password, password = a GitHub personal access token).
   - Branch: `*/main`   Script Path: `Jenkinsfile`
   - Save, then **Build Now**.

5. Watch the stages: Prepare, Lint and test, Build images, Scan with Trivy, Push to ECR,
   Deploy with Helm, Verify. The first run is slow (image pulls, Trivy database download).

6. See the app:

       make kubectl ARGS="get pods,svc,ingress,hpa -n aiops"
       make app-tunnel            # leave running, then open http://localhost:8081

## Things to know

- The pipeline polls Git every 5 minutes (Jenkins is private, so GitHub webhooks cannot reach it).
- The build fails on CRITICAL vulnerabilities that have a fix. If a base-image CVE blocks you,
  rebuild after `docker pull python:3.12-slim`, or temporarily raise the threshold in the Jenkinsfile.
- ECR pull credentials expire after 12 hours. Jenkins refreshes the `ecr-pull` secret on every
  deploy, so pods that restart much later could fail to pull until the next build runs.
  (A small CronJob that refreshes the secret is a good later improvement.)
- The Postgres password in `values.yaml` is a demo value. Override it with `--set postgres.password=...`.
