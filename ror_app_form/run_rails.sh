# run rails in insecure manner

# TODO: better server deployment / more secure
echo -e "\n  WARNING: Server is running in insecure way\n"

rails s -b 0.0.0.0 -p 8080
