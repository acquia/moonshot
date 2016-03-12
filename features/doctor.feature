Feature: doctor
  As a developer using moonshot
  I want help making sure my environment is setup correctly
  So that I can use other moonshot commands confidently.

  Background:
    Given I use the moonshot fixture "basic-app"
    And I default the environment variable "AWS_REGION" to "us-east-1"

  Scenario: `doctor` checks pass
    When I successfully run `environment doctor`
    Then the output should contain "CloudFormation template found"
    And the output should contain "CloudFormation template is valid."
    And the output should contain "Script 'script/build.sh' exists."

  Scenario: `doctor` fails when the script is missing
    Given I remove the file "script/build.sh"
    When I run `environment doctor`
    Then the output should contain "Could not find build script 'script/build.sh'!"
    And the exit status should be 1
