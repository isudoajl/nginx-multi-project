Analyze the conext to gain a deep undertanding about my project launcher project, analize too the @rule-production-deployment-always.mdc rule about production deployment because we are going to carry out real deployment in PRO env, run the creation script without the Cloudflare setup. The domain name is mapakms.com the project name is mapa-kms.

nix --extra-experimental-features "nix-command flakes" develop --command ./scripts/create-project-modular.sh --name my-project --port 9000 --domain mapakms.com

Pay attention always to the fact that the conf file of the nginx proxy point to the ip nginx containers
Check if our project creation script its creating the docker file in the way that the dockerfile copy the certificates inside the docker image, if not, take the approach best suit, all new project its going to have the same certificates, they are livin in :
/opt/nginx-multi-project/certs

Every time you strugle fixing bugs whether be manually editing conf files and you overcome the problem, you need to manually edit our script that the script implement that solution automatically in deployment time. After you fix a bug you need to make a new fresh deployment removing all the container, and all the projects inside /opt/nginx-multi-project/projects, I mean with a really clean env to test the script again:

podman stop -a && podman rm -a && rm -f proxy/conf.d/domains/*.conf && rm -rf projects/mapa-kms

Every time you need logs filter the last 5 lines, if its not enough filter the last 10 lines and so on..

Podman its our container solution
We are working with nix --extra-experimental-features "nix-command flakes" develop --command