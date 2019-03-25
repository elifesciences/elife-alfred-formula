import jenkins.model.Jenkins
import hudson.slaves.OfflineCause.SimpleOfflineCause
import org.jvnet.localizer.Localizable

class RetirementOfflineMessage extends org.jvnet.localizer.Localizable {
    def message
    RetirementOfflineMessage() {
        super(null, null, [])
        this.message = "Retired to update its underlying AMI"
    }
    String toString() {
        return this.message
    }
    String toString(java.util.Locale l) {
        toString()
    }
}

def cause = SimpleOfflineCause.create(new RetirementOfflineMessage())

println("Jenkins slaves: ${Jenkins.instance.slaves.size()}")
// TODO: clone list to use it in the next for()?
for (aSlave in Jenkins.instance.slaves) {
    if (aSlave.getLabelString() == 'containers-jenkins-plugin') {
		println("Retire: ${aSlave.name}")
        aSlave.getComputer().setTemporarilyOffline(true, cause)
        aSlave.getComputer().doDoDelete()
    } else {
		println("No action: ${aSlave.name}")
    }
}

println("Jenkins slaves after deletions started: ${Jenkins.instance.slaves.size()}")
for (aSlave in Jenkins.instance.slaves) {
    if (aSlave.getLabelString() == 'containers-jenkins-plugin') {
		println("Waiting for offline: ${aSlave.name}")
        aSlave.getComputer().waitUntilOffline()
		while (!aSlave.getComputer().isIdle()) {
			println("Waiting for idle: ${aSlave.name}")
			Thread.sleep(10000)
		}
		println("Delete: ${aSlave.name}")
        aSlave.getComputer().doDoDelete()
    }
}
