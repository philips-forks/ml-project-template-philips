import sys
from jupyter_server.auth import passwd

with open(f"{sys.argv[1]}/.jupyter/.env") as f:
    # password should be set in the first line of <repo_dir>/.jupyter_password
    entries = f.read().split("\n")
    password_entry = [e for e in entries if "jupyter_password" in e][0]
    password = password_entry.split("=")[1]

with open(f'{sys.argv[1]}/.jupyter/jupyter_server_config.json', 'w') as f:
    f.write('{"IdentityProvider": {"hashed_password": "%s"}}' % (passwd(password)))

with open(f'{sys.argv[1]}/.jupyter/jupyter_server_config.py', 'w') as f:
    f.write('c.ServerApp.ip = \'0.0.0.0\'\n')
