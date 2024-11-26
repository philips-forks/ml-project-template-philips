FROM nvcr.io/nvidia/pytorch:24.11-py3
ENV PYTHONUNBUFFERED=1


# ---------------------------------- Initializization -----------------------------------
# mkdir -p /root/.jupyter

RUN echo "############################# PROXY SETTINGS ##################################" >> /etc/environment && \
    echo "HTTP_PROXY=http://146.112.255.50:80" >> /etc/environment && \
    echo "HTTPS_PROXY=http://146.112.255.50:443" >> /etc/environment && \
    echo "NO_PROXY=localhost,127.0.0.1,.philips.com" >> /etc/environment && \
    echo "http_proxy=http://146.112.255.50:80" >> /etc/environment && \
    echo "https_proxy=http://146.112.255.50:443" >> /etc/environment && \
    echo "no_proxy=localhost,127.0.0.1,.philips.com" >> /etc/environment && \
    echo "REQUEST_CA_BUNDLE=/etc/ssl/certs/ciscoumbrella.pem" >> /etc/environment && \
    echo "NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/ciscoumbrella.crt" >> /etc/environment && \
    echo "###############################################################################" >> /etc/environment

RUN echo "############################# PROXY SETTINGS ##################################" >> /root/.bashrc && \
    echo "export HTTP_PROXY=http://146.112.255.50:80" >> /root/.bashrc && \
    echo "export HTTPS_PROXY=http://146.112.255.50:443" >> /root/.bashrc && \
    echo "export NO_PROXY=localhost,127.0.0.1,.philips.com" >> /root/.bashrc && \
    echo "export http_proxy=http://146.112.255.50:80" >> /root/.bashrc && \
    echo "export https_proxy=http://146.112.255.50:443" >> /root/.bashrc && \
    echo "export no_proxy=localhost,127.0.0.1,.philips.com" >> /root/.bashrc && \
    echo "export REQUEST_CA_BUNDLE=/etc/ssl/certs/ciscoumbrella.pem" >> /root/.bashrc && \
    echo "export NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/ciscoumbrella.crt" >> /root/.bashrc && \
    echo "###############################################################################" >> /root/.bashrc

RUN wget -O /usr/local/share/ca-certificates/ciscoumbrella.crt \
    https://d36u8deuxga9bo.cloudfront.net/certificates/Cisco_Umbrella_Root_CA.cer \
    && update-ca-certificates


# -------------------------- Install essential Linux packages ---------------------------
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    unzip \
    screen \
    tmux \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# ------------------- Configure Jupyter and Tensorboard individually --------------------
RUN echo "#!/bin/sh" > ~/init.sh

COPY .jupyter_password set_jupyter_password.py /root/.jupyter/

RUN pip install -U jupyterlab ipywidgets \
    && python /root/.jupyter/set_jupyter_password.py /root \
    && echo "/usr/local/bin/jupyter lab --allow-root --no-browser --notebook-dir=/code/notebooks &" >> ~/init.sh

RUN pip install -U tensorboard \
    && echo "/usr/local/bin/tensorboard --logdir=\$TB_DIR --bind_all" >> ~/init.sh \
    && echo "true" >> /root/.tensorboard_installed

RUN echo "sleep infinity" >> ~/init.sh

RUN chmod +x ~/init.sh

# ------------------------------------ Miscellaneous ------------------------------------
ENV TB_DIR=/ws/experiments
WORKDIR /code

CMD ["sh", "-c", "~/init.sh"]
