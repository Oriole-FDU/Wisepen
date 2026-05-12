# Custom Jenkins LTS image
# - 预装 JCasC + Job DSL + Pipeline 等插件
# - 由 deploy/middleware/profiles/jenkins.yml 通过 build context 引用
FROM jenkins/jenkins:lts

USER root

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
