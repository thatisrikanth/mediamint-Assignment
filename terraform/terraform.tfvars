aws_region      = "ap-south-2"
environment     = "production"

# Leave this empty during your initial bootstrap phase. 
# The GitHub Actions workflow will dynamically override this parameter 
# using the "-var" flag or environmental variables on subsequent runs.
container_image = ""
