import jenkins.model.Jenkins

def newAmiId = args[0]

Jenkins jenkins = Jenkins.getInstance()
def oldAmiId = jenkins.clouds[0].templates[0].ami
println("Old AMI: ${oldAmiId}")

jenkins.clouds[0].templates[0].ami = newAmiId
jenkins.save()
println("New AMI: ${newAmiId}")
