import com.android.apksig.ApkVerifier;
import java.io.File;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.util.HexFormat;
import java.util.Set;
import java.util.TreeSet;

class CompareApkSigners {
    static Set<String> fingerprints(String path) throws Exception {
        var result = new ApkVerifier.Builder(new File(path)).build().verify();
        if (!result.isVerified()) {
            throw new SecurityException("Invalid APK signature: " + result.getErrors());
        }
        var digests = new TreeSet<String>();
        var sha256 = MessageDigest.getInstance("SHA-256");
        for (X509Certificate signer : result.getSignerCertificates()) {
            digests.add(HexFormat.of().formatHex(sha256.digest(signer.getEncoded())));
        }
        if (digests.isEmpty()) {
            throw new SecurityException("APK has no verified signing certificates");
        }
        return digests;
    }

    public static void main(String[] args) throws Exception {
        var published = fingerprints(args[0]);
        var candidate = fingerprints(args[1]);
        System.out.println("Published signing certificates: " + published);
        System.out.println("Candidate signing certificates: " + candidate);
        if (!published.equals(candidate)) {
            throw new SecurityException("APK signing identities differ");
        }
    }
}
