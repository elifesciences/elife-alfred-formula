import jenkins.model.Jenkins

def amiId = args[0]

Jenkins jenkins = Jenkins.getInstance()
def ami = jenkins.clouds[0].templates[0].ami
println("Current AMI: ${ami}")

jenkins.clouds[0].templates[0].ami = amiId
jenkins.save()
