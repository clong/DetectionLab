terraform {     
  required_version = ">= 0.13"                                                                                                                                                                                                    
  required_providers {                                                                                                                                                                                              
    esxi = {                                                                                                                                                                                                        
      source = "josenk/esxi"                                                                                                                                                                                        
      version = "1.8.0"                                                                                                                                                                                             
    }
  }
}