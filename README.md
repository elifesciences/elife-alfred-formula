# `elife-alfred` formula

This repository contains instructions for installing and configuring the `elife-alfred` project.

This repository should be structured as any Saltstack formula should, but it 
should also conform to the structure required by the [builder](https://github.com/elifesciences/builder) 
project.

See the eLife [builder example project](https://github.com/elifesciences/builder-example-project)
for a reference on how to integrate with the `builder` project.

[MIT licensed](LICENCE.txt)

## Rationale

We are using Jenkins 2 to build pipelines of jobs that checkout projects, test them in a variety of ways and finally deploy to a production environment. New commits move through the pipeline and they are stopped at each stage if they fail the verification of project tests (that span a single Github project) or end-to-end tests (which connect all projects together).

## Jenkins 2

Jenkins 2 provides a Pipeline plugin by default (evolution of the Workflow plugin) which allows to organize the pipeline of a project in a graphical way:
- from left to right a new commit move through the stages
- from bottom to top new commits are added and tested

Jenkins 2 pipelines are defined as groovy scripts such as:

```
elifePipeline {
    stage 'Checkout'
    checkout scm
    def commit = elifeGitRevision()

    stage 'Project tests'
    lock('journal--ci') {
        builderDeployRevision 'journal--ci', commit
        builderProjectTests 'journal--ci', '/srv/journal'
        def phpunitTestArtifact = "${env.BUILD_TAG}.phpunit.xml"
        builderTestArtifact phpunitTestArtifact, 'journal--ci', '/srv/journal/build/phpunit.xml'
        def behatTestArtifact = "${env.BUILD_TAG}.behat.xml"
        builderTestArtifact behatTestArtifact, 'journal--ci', '/srv/journal/build/behat.xml'
        elifeVerifyJunitXml phpunitTestArtifact
        elifeVerifyJunitXml behatTestArtifact
    }

    elifeMainlineOnly {
        stage 'Deploy on end2end'
        builderDeployRevision 'journal--end2end', commit

        stage 'Deploy on demo'
        builderDeployRevision 'journal--demo', commit

        stage 'Approval'
        elifeGitMoveToBranch commit, 'approved'
    }
}
```

This pipeline has 5 stages; more can be added with other `stage` sections.
`sh` steps run scripts inside the workspace where the project has been checked out with the new commit. `step` statements can delegate to any generic Jenkins step.

All the `elife*` and `builder*` elements in the pipeline definition are provided by a [Git repository of custom steps](https://github.com/elifesciences/elife-jenkins-workflow-libs) (written in Groovy too) that is imported into Jenkins. These steps are pushed to the remote `ssh://$USERNAME@$JENKINS:16022/workflowLibs.git` to deploy them into the Jenkins instance.

### Pipelines

- `test-*` pipelines bring a project from `develop` to `approved` if it passed all specified tests.
- `production-*` pipelines bring a project from `approved` to `master` and deploy it.
- `library-*` pipelines builds the `master` of libraries, which have no standalone deploy.
- `Pull Requests (*)` folders contain one subfolder per-project. They build the branches of pull requests to the official repositories (no forks) according to their Jenkinsfile.

Not all the projects are in `Pull requests`: they have to be whitelisted in its configurations. Libraries are easily supported, as their builds are stateless and parallelizable; projects instead need the pipeline to take a `lock` step over the `ci` machine being used.

### Plugins

Most of the interesting Jenkins features are provided by plugins, which are backed up with Alfred's Jenkins installation.

- `Pipeline` and all its dependencies to define pipelines and do so through `Jenkinsfile`s.
- `Build Monitor View` to show a coarse grained view of the status of the builds.
- `Extra Columns Plugin` to configure views with arbitrary information.
- `Github Plugin` for integrating with Github projects, e.g. receiving hooks for triggering new builds.
- `Github Authentication Plugin` to make users log in with their Github account through OAuth.
- `Github Organization Folder Plugin` and its dependency `Github Branch Source Plugin` to build branches of main repositories and any pull request directed to them.
- `SSH Slaves Plugin` to log into slave machines and run builds over there.
- `Thin Backup` for backupping Jenkins, its plugins and its configuration.
- `Workspace Cleanup Plugin` to free space from workspaces remains after a build has finished.

## Builder

Under the covers Jenkins is delegating the deployment of projects and their test runs to builder. The stack is composed as follows:

- `/srv/builder` is the modern, open sourced builder.
- `/usr/local/jenkins-scripts` contains miscellaneous scripts like `verifyjunitxml.py` that can be run without external dependencies. Nothing very interesting.

## Project conventions

In order to provide a consistent infrastructure for every project and a single dashboard for their test suite status and quality metrics, it's important to have a least common denominator between their test suites and infrastructure. Here's what a project should do.

### Scripts

- have an executable `project_tests.sh` files which runs the project's own tests and exiting with 0 only if the tests are successful.
- Have `project_tests.sh` produce a `build/*.xml` file with the results of the build in the standard JUnit XML format. The 'build/' folder may be used in the future to collect other information, such as static analysis, linting and coverage results. More than one `build/*.xml` file (e.g. PHPUnit and PHPSpec) are welcome.
- Be ready to work after the `./bldr deploy:$stackname,$cluster` command has finished running. No necessity for starting something manually when in `end2end`, `continuumtest` and `prod`. For previous environments "ready to work" means ready to run the project tests.

### Configurations

- Support the `dev` and `ci` configurations: used in `dev`elopment and in the `ci` testing cluster, this configuration isolates the project from other projects and the external world. Unit tests and code coverage metrics run at this level, providing feedback over the basic correctness and quality of the code. **`default`**, **`testing`** and **`development`** will become `dev` (and `ci`, which should be very similar apart from occasional hostnames like `develop--ci.lax.elifesciences.org`).
- Support the `end2end` configuration: used in the `end2end` testing cluster, this configuration connects the project to all its `end2end` neighbors and allows to run tests which move data between projects and test their collaboration. Still this configuration stubs external dependencies not under the administration of eLife (e.g. PMC) or use their preproduction services where provided.
- Support the `continuumtest` configuration: used in the `continuumtest` exploratory cluster to run manual tests and exploratory tests where a human eye is needed. This configuration connects each project to its `continuumtest` neighbors.
- Support the `prod` configuration: used in the `prod` cluster, this configuration is the one that serves the real user. It connects all projects together and with the real world. **`production`** and **`live`** become `prod`.

It is more important for the cluster names to be consistent than to be perfectly fitting. It should be impossible for clusters to communicate with each other (i.e. if it happens something is horribly wrong).

The configuration of a project is chosen according to the stack where it is deployed (e.g. `elife-bot--continuumtest` vs. `elife-bot--ci` vs. `lax--end2end`) The configuration will not be chosen according to the branch that is deployed; if we have experimental branches the target is to deploy them on separate stacks, that live and die with the branch/pull request.

### Branches

- Pull requests should be directed at `develop`. The project tests should always be runnable over a branch, while the end2end tests are limited to run on the mainline right now.
- It is the project's pipeline responsibility to merge `develop` into `approved` when all automated tests are passing.
- It is the project's pipeline responsibility to merge `approved` into `master` upon deployment into production, which happens by triggering the `prod-$PROJECT` pipeline manually (or optionally automatically upon arrival into `approved` if the project owners feel confident.)
- Whatever branch can be deployed on the `continuumtest` instances, but if you want the most recent version of the code that has passed all tests you should go for the `approved` branch.

Given the current state of things, project tests can be run either on TravisCI or on Jenkins itself (or possibly on both), whereas end2end tests can run only on Jenkins and the main develop branch. The project tests will be removed from TravisCI and brought to Jenkins only in the moment in which it is able to build branches.
