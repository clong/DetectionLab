terraform {     
  required_version = ">= 1.0.0"                                                                                                                                                                                                    
  required_providers {                                                                                                                                                                                              
    esxi = {                                                                                                                                                                                                        
      source = "josenk/esxi"                                                                                                                                                                                        
      version = "1.8.2"                                                                                                                                                                                             
    }
  }
}