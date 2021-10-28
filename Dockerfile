FROM continuumio/miniconda3

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install essential Linux packages
RUN apt-get update \
    && apt-get install -y build-essential git curl wget unzip vim \
    && rm -rf /var/lib/apt/lists/* \
    && conda init

# Install dependencies
COPY environment.yaml /root/conda_environment.yaml
RUN conda env update -n base -f /root/conda_environment.yaml --prune \
    && conda clean --all --yes

# Add user to avoid root access to attached dirs
ARG username=user
ARG uid=1000
RUN groupadd -g $uid $username \
    && useradd -u $uid -g $uid -s /bin/bash -d /home/$username $username \
    && mkdir /home/$username \
    && chown -R $username:$username /home/$username

# Configure Jupyter
COPY .jupyter_password set_jupyter_password.py /home/$username/.jupyter/
RUN conda install jupyterlab
RUN python /home/$username/.jupyter/set_jupyter_password.py $username

USER $username
WORKDIR /code

CMD ["jupyter", "lab", "--no-browser"]
