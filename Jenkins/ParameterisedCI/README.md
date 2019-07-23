# Commit-based Parameterised Continuous Integration Pipeline
While using a Multibranch pipeline in Jenkins with automatic triggers, it is a challenge to specify certain parameters that may be unique to different codebases, branches or even commits.

This is a basic reference implementation of using a Multibranch Pipeline with an options file embedded in the codebase to allow for passing parameters to, and through the pipeline.

You can add multiple different kinds of parameters to the JSON file to do whatever you please with. THe example lists a few that I've used in the past, specifying which stages of the pipeline I'd like to run, whether to email results of the pipeline to my email and also as a means for selecting an AWS AMI to use specifically for my build server.