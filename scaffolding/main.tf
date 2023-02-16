terraform {
  cloud {
    organization = "larryclaman"
    workspaces {
      # This will choose all workspaces with this tag.  
      # You will need to subsequently select the workspace for the run, eg 'terraform workspace select prod'
      # or you will need to set the TF_WORKSPACE env variable
      tags = ["azure-vm-ref-arch"]
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.26.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Accept terms
resource "azurerm_marketplace_agreement" "flatcar" {
  publisher = "kinvolk"
  offer     = "flatcar-container-linux-free"
  plan      = "stable-gen2"
}