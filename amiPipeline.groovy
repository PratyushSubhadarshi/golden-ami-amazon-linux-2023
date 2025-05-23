#!groovy

def call(Map config) {
    agentLabel        = config?.agentLabel ?: 'c5_2xlarge_ubuntu_20_04_spot'
    buildImage        = config?.buildImage ?: 'plivo/jenkins-ci/ami-builder:0.0.21'
    buildNumToKeep    = config?.buildNumToKeep?.toString() ?: '50'
    artifactNumToKeep = config?.artifactNumToKeep?.toString() ?: '50'
    timeoutHrs        = config?.timeoutHrs?.toInteger() ?: 2

    pipeline {
        agent {
            label agentLabel
        }

        options {
            buildDiscarder(logRotator(numToKeepStr: buildNumToKeep, artifactNumToKeepStr: artifactNumToKeep))
            timeout(time: timeoutHrs, unit: 'HOURS')
            timestamps()
            skipStagesAfterUnstable()
            disableConcurrentBuilds()
        }

        stages {
            stage('Checkout') {
                steps {
                    checkout scm
                }
            }

            stage('Build AMI') {
                agent { 
                    docker {
                        image buildImage
                        args "--entrypoint=''"
                        reuseNode true
                    }
                }

                steps {
                    withCredentials([sshUserPrivateKey(credentialsId: 'PLIVO_JENKINS_SSH', keyFileVariable: 'SSH_PRIVATE_KEY')]) {
                        sh 'mkdir -p ~/.ssh'
                        sh "cp -vf ${SSH_PRIVATE_KEY} ~/.ssh/id_rsa"
                        sh "ssh-keyscan -H 'github.com' >> ~/.ssh/known_hosts"
                    }

                    withEnv(['PACKER_PLUGIN_PATH=' + pwd()]){
                        withAWS(region: 'us-west-1', credentials: 'PLIVO-DEVOPS-PACKER') {
                            echo 'Initializing packer...'
                            sh 'packer init .'
                            echo 'Validating packer file...'
                            sh 'packer validate .'
                            echo 'Building AMI...'
                            sh 'packer build .'
                        }
                    }
                }

                post {
                    success {
                        archiveArtifacts artifacts: 'packer-manifest.json',
                            allowEmptyArchive: true,
                            fingerprint: true
                    }
                }
            }
        }

        post {
            always {
                cleanWs()
                deleteDir()
            }
        }
    }
}
