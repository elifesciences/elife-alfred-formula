import jenkins.model.Jenkins

project = args[0]

Jenkins jenkins = Jenkins.getInstance()
folder = jenkins.getItemByFullName("pull-requests-projects")
projectFolder = folder.getItemByProjectName(project)
if (!projectFolder) {
    return;
}
for (pullRequest in projectFolder.getItems()) {
    if (!pullRequest.buildable) {
        println(pullRequest.getName() - "PR-")
    }
}
