[CCode (cheader_filename = "sys/file.h")]
namespace Posix {
    [Flags]
    public enum FlockType {
        [CCode (cname = "LOCK_SH")]
        SHARED,
        [CCode (cname = "LOCK_EX")]
        EXCLUSIVE,
        [CCode (cname = "LOCK_UN")]
        UNLOCK,
        [CCode (cname = "LOCK_NB")]
        NONBLOCKING
    }
    [CCode (cname = "flock")]
    public int flock(int fd, FlockType operation);
}
