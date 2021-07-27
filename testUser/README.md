# NAME

BeakerLib library testUser

# DESCRIPTION

This library provide s function for maintaining testing users.

# USAGE

To use this functionality you need to import library distribution/testUser and add
following line to Makefile.

        @echo "RhtsRequires:    library(distribution/testUser)" >> $(METADATA)

# VARIABLES

- testUser

    Array of testing user login names.

- testUserDefaultName

    A name of the user account which will be used while creating users,
    a number will be added at the end.

    Needs to be set before the user accounts are created.

    Defaut is 'testuser'.

- testUserPasswd

    Array of testing users passwords.

- testUserDefaultPasswd

    A password of the user account which will be used while creating users.

    Needs to be set before the user accounts are created.

    Defaut is 'foobar'.

- testUserUID

    Array of testing users UIDs.

- testUserGID

    Array of testing users primary GIDs.

- testUserGroup

    Array of testing users primary group names.

- testUserGIDs

    Array of space separated testing users all GIDs.

- testUserGroups

    Array of space separated testing users all group names.

- testUserGecos

    Array of testing users gecos fields.

- testUserHomeDir

    Array of testing users home directories.

- testUserShell

    Array of testing users default shells.

# FUNCTIONS

### testUserSetup, testUserCleanup

Creates/removes testing user(s).

    rlPhaseStartSetup
        testUserSetup [--fast] [NUM]
    rlPhaseEnd

    rlPhaseStartCleanup
        testUserCleanup
    rlPhaseEnd

- --fast

    Use newusers, mkdir, chmod, and chown for user(s) creation.
    And direct home dir removal, edit of /etc/passwd, /etc/shadow, /etc/group,
    and /etc/gshadow/ for user(s) removal.

    This will be automatically propagated to testUserAdd and testUserDel is called
    separately.

- NUM

    Optional number of user to be created. If not specified one user is created.

Returns 0 if success.

### testUserAdd, testUserDel

Creates/removes further testing user(s).

    testUserAdd [--fast] [NUM]
    testUserDel [--fast] [USERNAME]
    testUserDel [--fast]

- --fast

    Use newusers, mkdir, chmod, and chown for user(s) creation.
    And direct home dir removal, edit of /etc/passwd, /etc/shadow, /etc/group,
    and /etc/gshadow/ for user(s) removal.

- NUM

    Optional number of user to be created. If not specified one user is created.

- USERNAME

    A user to be deleted.

Returns 0 if success.

# AUTHORS

- Dalibor Pospisil <dapospis@redhat.com>
