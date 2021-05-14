variable "region"{
    default = "ap-south-1" 
}
variable "tags"{
    type = list
    default=["Entstance1","Enstance2"]
}
variable "ami"{
     type = map
     default ={
         "ap-south-1"="ami-010aff33ed5991201"
         "ap-south-1"="ami-04bde106886a53080"
     }
}     
variable "elb_name"{
    type= string
    default= "myelb"
}
variable "az"{
    type =list
    default=["ap-south-1a","ap-south-1b"]
}
variable "timeout"{
    type = number
    default="400"
}
