FROM condaforge/mambaforge
ENV PYTHONUNBUFFERED 1


# ------------------- Add user to avoid root access to attached dirs --------------------
ARG username=user
ARG groupname=user
ARG uid=1000
ARG gid=1000
ARG userpwd=passwd
RUN groupadd -f -g $gid $groupname \
    && useradd -u $uid -g $gid -s /bin/bash -d /home/$username $username \
    && sh -c "echo $username:$userpwd | chpasswd" \
    && mkdir -p /home/$username/.ssh \
    && echo export PATH=$PATH > /etc/environment \
    && echo export http_proxy=$http_proxy >> /etc/environment \
    && echo export https_proxy=$https_proxy >> /etc/environment \
    && echo export HTTP_PROXY=$HTTP_PROXY >> /etc/environment \
    && echo export HTTPS_PROXY=$HTTPS_PROXY >> /etc/environment \
    && echo "Acquire::http::Proxy \"$HTTP_PROXY\";" >> /etc/apt/apt.conf.d/10proxy \
    && echo "Acquire::https::Proxy \"$HTTPS_PROXY\";" >> /etc/apt/apt.conf.d/10proxy \
    && chown -R $username:$groupname /home/$username \
    && chown -R $username:$groupname /opt/conda


# -------------------------- Install essential Linux packages ---------------------------
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    git \
    git-lfs \
    curl \
    wget \
    unzip \
    vim \
    screen \
    tmux \
    python3-opencv \
    openssh-server \
    && mkdir /var/run/sshd \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install


# ----------------------------------- Switch to user ------------------------------------
USER $username


# ----------------------------- Install conda dependencies ------------------------------
COPY environment.yaml /home/$username/conda_environment.yaml
COPY requirements.txt /home/$username/requirements.txt
RUN conda update -n base conda \
    && conda env update -n base -f /home/$username/conda_environment.yaml --prune \
    && xargs -L 1 pip install --no-cache-dir < /home/$username/requirements.txt
 

# ------------------- Configure Jupyter and Tensorboard individually --------------------
COPY --chown=$username:$groupname .jupyter_password set_jupyter_password.py /home/$username/.jupyter/
RUN conda install -y jupyterlab ipywidgets tensorboard \
    && python /home/$username/.jupyter/set_jupyter_password.py $username

RUN echo "#!/bin/sh" > ~/init.sh \
    && echo "/opt/conda/bin/jupyter lab --no-browser &" >> ~/init.sh \
    && echo "/opt/conda/bin/tensorboard --logdir=\$TB_DIR --bind_all" >> ~/init.sh \
    && chmod +x ~/init.sh

RUN conda clean --all --yes


# ------------------------------------ Miscellaneous ------------------------------------
ENV TB_DIR=/ws/experiments
WORKDIR /code
EXPOSE 8888
EXPOSE 6006
EXPOSE 22

CMD ~/init.sh
