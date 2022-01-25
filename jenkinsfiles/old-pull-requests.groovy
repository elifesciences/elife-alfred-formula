import jenkins.model.Jenkins

project = args[0]

// API docs: https://javadoc.jenkins-ci.org/jenkins/model/jenkins.html
Jenkins jenkins = Jenkins.getInstance()
folder = jenkins.getItemByFullName("pull-requests-projects") // => "https://alfred.elifesciences.org/job/pull-requests-projects/"
projectFolder = folder.getItemByProjectName(project) //         => "https://alfred.elifesciences.org/job/pull-requests-projects/job/journal/"
if (!projectFolder) {
    return;
}

// [org.jenkinsci.plugins.workflow.job.WorkflowJob@11e2c35c[pull-requests-projects/journal/PR-1367],
//  org.jenkinsci.plugins.workflow.job.WorkflowJob@3ff2adcf[pull-requests-projects/journal/PR-1429], 
//  org.jenkinsci.plugins.workflow.job.WorkflowJob@d77b908[pull-requests-projects/journal/PR-1470]]
for (pullRequest in projectFolder.getItems()) {
    if (!pullRequest.buildable) { // "Returns true if we should display 'build now' icon"
        println(pullRequest.getName() - "PR-") // "PR-1367" => "1367"
    }
}
