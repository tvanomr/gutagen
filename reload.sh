#!/bin/bash
git pull
docker rm -f interviewgenerator
docker build -t interviewgenerator .
docker run -d --name interviewgenerator -e "VIRTUAL_HOST=interviewgenerator.dit.life" -e "VIRTUAL_PORT=24433" -e "LETSENCRYPT_HOST=interviewgenerator.dit.life" -e "LETSENCRYPT_EMAIL=s@oxton.ru" -v $(pwd)/logs:/var/log interviewgenerator