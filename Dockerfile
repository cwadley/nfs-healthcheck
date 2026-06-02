FROM alpine:3.19

COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

ENV MOUNT_PATH=/mnt/nfs

# start-period gives the host time to bring up the NFS mount without counting
# early failures; once the mount appears the single-shot check flips to healthy.
HEALTHCHECK --interval=5s --timeout=5s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

CMD ["tail", "-f", "/dev/null"]
