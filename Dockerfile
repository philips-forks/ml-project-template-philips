FROM nvcr.io/nvidia/pytorch:25.06-py3
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

RUN echo "#!/bin/sh" > ~/start.sh \
    && echo "sleep infinity" >> ~/start.sh \
    && chmod +x ~/start.sh

# ------------------------------------ Miscellaneous ------------------------------------
ENV TB_DIR=/ws/experiments
WORKDIR /code

CMD ["sh", "-c", "~/start.sh"]
