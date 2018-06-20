#!/bin/sh

ARTIFACT_SUBDIR=${FBSD_BRANCH}/r${SVN_REVISION}/${TARGET}/${TARGET_ARCH}

mkdir -p ${ARTIFACTS_DIR}

cd ${ARTIFACTS_DIR}
for f in ${DIST_PACKAGES}
do
	fetch -m https://artifact.ci.freebsd.org/snapshot/${ARTIFACT_SUBDIR}/${f}.txz
done
cd -
