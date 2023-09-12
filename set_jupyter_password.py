import sys
from jupyter_server.auth import passwd

with open(f"{sys.argv[1]}/.jupyter/.jupyter_password") as f:
    # password should be set in the first line of <repo_dir>/.jupyter_password
    password = f.read().split("\n")[0]

with open(f'{sys.argv[1]}/.jupyter/jupyter_server_config.json', 'w') as f:
    f.write('{"IdentityProvider": {"hashed_password": "%s"}}' % (passwd(password)))

with open(f'{sys.argv[1]}/.jupyter/jupyter_server_config.py', 'w') as f:
    f.write('c.ServerApp.ip = \'0.0.0.0\'\n')
