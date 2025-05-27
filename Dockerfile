FROM nvcr.io/nvidia/pytorch:24.11-py3
ENV PYTHONUNBUFFERED=1


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

COPY .env set_jupyter_password.py /root/.jupyter/

RUN pip install -U jupyterlab ipywidgets \
    && python /root/.jupyter/set_jupyter_password.py /root \
    && echo "/usr/local/bin/jupyter lab --allow-root --no-browser --notebook-dir=/code/notebooks &" >> ~/init.sh

RUN pip install -U tensorboard \
    && mkdir -p /ws/tensorboard_logs \
    && echo "/usr/local/bin/tensorboard --logdir=/ws/tensorboard_logs --bind_all" >> ~/init.sh \
    && echo "true" >> /root/.tensorboard_installed

RUN echo "sleep infinity" >> ~/init.sh

RUN chmod +x ~/init.sh

# ------------------------------------ Miscellaneous ------------------------------------
ENV TB_DIR=/ws/experiments
WORKDIR /code

CMD ["sh", "-c", "~/init.sh"]
