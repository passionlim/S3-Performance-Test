package de.jeha.s3pt.operations;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.s3.model.S3ObjectInputStream;
import de.jeha.s3pt.OperationResult;
import de.jeha.s3pt.operations.data.ObjectKeys;
import de.jeha.s3pt.operations.data.S3ObjectKeysDataProvider;
import de.jeha.s3pt.operations.data.SingletonFileObjectKeysDataProvider;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.time.StopWatch;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


import java.io.IOException;
import java.nio.ByteBuffer;

/**
 * @author jenshadlich@googlemail.com
 */
public class RandomRead extends AbstractOperation {

    private static final Logger LOG = LoggerFactory.getLogger(RandomRead.class);

    private final AmazonS3 s3Client;
    private final String bucket;
    private final int n;
    private final String keyFileName;

    public RandomRead(AmazonS3 s3Client, String bucket, int n, String keyFileName) {
        this.s3Client = s3Client;
        this.bucket = bucket;
        this.n = n;
        this.keyFileName = keyFileName;
    }

    @Override
    public OperationResult call() {
        LOG.info("Random read: n={}", n);

        final ObjectKeys objectKeys;
        if (keyFileName == null) {
            objectKeys = new S3ObjectKeysDataProvider(s3Client, bucket).get();
        } else {
            objectKeys = new SingletonFileObjectKeysDataProvider(keyFileName).get();
        }
        StopWatch stopWatch = new StopWatch();

        for (int i = 0; i < n; i++) {
            final String randomKey = objectKeys.getRandom();
            LOG.debug("Read object: {}", randomKey);

            stopWatch.reset();
            stopWatch.start();

            S3Object object = s3Client.getObject(bucket, randomKey);
            long expectedSize = object.getObjectMetadata().getContentLength();

            try {
                S3ObjectInputStream is = object.getObjectContent();
                byte[] buffer = new byte[8096];
                long totalSize = 0 ;

                int size;

                while((size = is.read(buffer)) != -1 )  {
                    totalSize += size;
                }

                if ( expectedSize != totalSize ) {
                    LOG.warn("The expected size of object is different from actual read bytes." + randomKey);
                } else {
                    LOG.info(expectedSize + " bytes has been read." + randomKey);
                }

            } catch (IOException e) {
                LOG.warn("An exception occurred while trying to close object with key: {}", randomKey);
            } finally {
                IOUtils.closeQuietly(object);
            }

            stopWatch.stop();

            LOG.debug("Time = {} ms", stopWatch.getTime());
            getStats().addValue(stopWatch.getTime());

            if (i > 0 && i % 1000 == 0) {
                LOG.info("Progress: {} of {}", i, n);
            }
        }

        return new OperationResult(getStats());
    }

}
