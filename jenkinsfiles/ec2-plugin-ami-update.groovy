import jenkins.model.Jenkins

Jenkins jenkins = Jenkins.getInstance()
def ami = jenkins.clouds[0].templates[0].ami
echo "Current AMI: ${ami}"

jenkins.clouds[0].templates[0].ami = 'ami-0d0bb287bec9a4f8a'
jenkins.save()
