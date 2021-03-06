(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

(*
The main architecture independent data types and type definitions in
the abstract model.
*)

header "Basic Data Structures"

theory Structures_A
imports
  ARM_Structs_A
  "../machine/MachineOps"
begin

text {*
  User mode can request these objects to be created by retype:
*}
datatype apiobject_type =
    Untyped
  | TCBObject
  | EndpointObject
  | AsyncEndpointObject
  | CapTableObject
  | ArchObject aobject_type


text {* These allow more informative type signatures for IPC operations. *}
type_synonym badge = data
type_synonym msg_label = data
type_synonym message = data


text {* This type models refences to capability slots. The first element
  of the tuple points to the object the capability is contained in. The second
  element is the index of the slot inside a slot-containing object. The default
  slot-containing object is a cnode, thus the name @{text cnode_index}.
*}
type_synonym cnode_index = "bool list"
type_synonym cslot_ptr = "obj_ref \<times> cnode_index"


text {* Capabilities. Capabilities represent explicit authority to perform some
action and are required for all system calls. Capabilities to Endpoint,
AsyncEndpoint, Thread and CNode objects allow manipulation of standard kernel
objects. Untyped capabilities allow the creation and removal of kernel objects
from a memory region. Reply capabilities allow sending a one-off message to
a thread waiting for a reply. IRQHandler and IRQControl caps allow a user to
configure the way interrupts on one or all IRQs are handled. Capabilities to
architecture-specific facilities are provided through the @{text arch_cap} type.
Null capabilities are the contents of empty capability slots; they confer no
authority and can be freely replaced. Zombie capabilities are stored when
the deletion of CNode and Thread objects is partially completed; they confer no
authority but cannot be replaced until the deletion is finished.
*}

datatype cap
         = NullCap
         | UntypedCap obj_ref nat nat
           -- {* pointer, size in bits (i.e. @{text "size = 2^bits"}) and freeIndex (i.e. @{text "freeRef = obj_ref + (freeIndex * 2^4)"}) *}
         | EndpointCap obj_ref badge cap_rights
         | AsyncEndpointCap obj_ref badge cap_rights
         | ReplyCap obj_ref bool
         | CNodeCap obj_ref nat "bool list"
           -- "CNode ptr, number of bits translated, guard"
         | ThreadCap obj_ref
         | DomainCap
         | IRQControlCap
         | IRQHandlerCap irq
         | Zombie obj_ref "nat option" nat
           -- {* @{text "cnode ptr * nat + tcb or cspace ptr"} *}
         | ArchObjectCap arch_cap

text {* The CNode object is an array of capability slots. The domain of the
function will always be the set of boolean lists of some specific length.
Empty slots contain a Null capability.
*}
type_synonym cnode_contents = "cnode_index \<Rightarrow> cap option"

text {* Various access functions for the cap type are defined for
convenience. *}
definition
  the_cnode_cap :: "cap \<Rightarrow> obj_ref \<times> nat \<times> bool list" where
  "the_cnode_cap cap \<equiv>
  case cap of
    CNodeCap oref bits guard \<Rightarrow> (oref, bits, guard)"

definition
  the_arch_cap :: "cap \<Rightarrow> arch_cap" where
  "the_arch_cap cap \<equiv> case cap of ArchObjectCap a \<Rightarrow> a"

primrec
  cap_ep_badge :: "cap \<Rightarrow> badge"
where
  "cap_ep_badge (EndpointCap _ badge _) = badge"
| "cap_ep_badge (AsyncEndpointCap _ badge _) = badge"

primrec
  cap_ep_ptr :: "cap \<Rightarrow> badge"
where
  "cap_ep_ptr (EndpointCap obj_ref _ _) = obj_ref"
| "cap_ep_ptr (AsyncEndpointCap obj_ref _ _) = obj_ref"

definition
  bits_of :: "cap \<Rightarrow> nat" where
  "bits_of cap \<equiv> case cap of
    UntypedCap _ bits _ \<Rightarrow> bits
  | CNodeCap _ radix_bits _ \<Rightarrow> radix_bits"

definition
  free_index_of :: "cap \<Rightarrow> nat" where
  "free_index_of cap \<equiv> case cap of
    UntypedCap _ _ free_index \<Rightarrow> free_index"

definition
  is_reply_cap :: "cap \<Rightarrow> bool" where
  "is_reply_cap cap \<equiv> case cap of ReplyCap _ m \<Rightarrow> \<not> m | _ \<Rightarrow> False"
definition
  is_master_reply_cap :: "cap \<Rightarrow> bool" where
  "is_master_reply_cap cap \<equiv> case cap of ReplyCap _ m \<Rightarrow> m | _ \<Rightarrow> False"
definition
  is_zombie :: "cap \<Rightarrow> bool" where
  "is_zombie cap \<equiv> case cap of Zombie _ _ _ \<Rightarrow> True | _ \<Rightarrow> False"
definition
  is_arch_cap :: "cap \<Rightarrow> bool" where
  "is_arch_cap cap \<equiv> case cap of ArchObjectCap _ \<Rightarrow> True | _ \<Rightarrow> False"

fun is_cnode_cap :: "cap \<Rightarrow> bool"
where
  "is_cnode_cap (CNodeCap _ _ _) = True"
| "is_cnode_cap _                = False"

fun is_thread_cap :: "cap \<Rightarrow> bool"
where
  "is_thread_cap (ThreadCap _) = True"
| "is_thread_cap _             = False"

fun is_domain_cap :: "cap \<Rightarrow> bool"
where
  "is_domain_cap DomainCap = True"
| "is_domain_cap _ = False"

fun is_untyped_cap :: "cap \<Rightarrow> bool"
where
  "is_untyped_cap (UntypedCap _ _ _) = True"
| "is_untyped_cap _                  = False"

fun is_ep_cap :: "cap \<Rightarrow> bool"
where
  "is_ep_cap (EndpointCap _ _ _) = True"
| "is_ep_cap _                   = False"

fun is_aep_cap :: "cap \<Rightarrow> bool"
where
  "is_aep_cap (AsyncEndpointCap _ _ _) = True"
| "is_aep_cap _                        = False"

primrec
  cap_rights :: "cap \<Rightarrow> cap_rights"
where
  "cap_rights (EndpointCap _ _ cr) = cr"
| "cap_rights (AsyncEndpointCap _ _ cr) = cr"
| "cap_rights (ArchObjectCap acap) = acap_rights acap"

text {* Various update functions for cap data common to various kinds of
cap are defined here. *}
definition
  cap_rights_update :: "cap_rights \<Rightarrow> cap \<Rightarrow> cap" where
  "cap_rights_update cr' cap \<equiv>
   case cap of
     EndpointCap oref badge cr \<Rightarrow> EndpointCap oref badge cr'
   | AsyncEndpointCap oref badge cr
     \<Rightarrow> AsyncEndpointCap oref badge (cr' - {AllowGrant})
   | ArchObjectCap acap \<Rightarrow> ArchObjectCap (acap_rights_update cr' acap)
   | _ \<Rightarrow> cap"

text {* For implementation reasons not all bits of the badge word can be used. *}
definition
  badge_bits :: nat where
  "badge_bits \<equiv> 28"

declare badge_bits_def [simp]

definition
  badge_update :: "badge \<Rightarrow> cap \<Rightarrow> cap" where
  "badge_update data cap \<equiv>
   case cap of
     EndpointCap oref badge cr \<Rightarrow> EndpointCap oref (data && mask badge_bits) cr
   | AsyncEndpointCap oref badge cr \<Rightarrow> AsyncEndpointCap oref (data && mask badge_bits) cr
   | _ \<Rightarrow> cap"


definition
  mask_cap :: "cap_rights \<Rightarrow> cap \<Rightarrow> cap" where
  "mask_cap rights cap \<equiv> cap_rights_update (cap_rights cap \<inter> rights) cap"

section {* Message Info *}

text {* The message info is the first thing interpreted on a user system call
and determines the structure of the message the user thread is sending either to
another user or to a system service. It is also passed to user threads receiving
a message to indicate the structure of the message they have received. The
@{text mi_length} parameter is the number of data words in the body of the
message. The @{text mi_extra_caps} parameter is the number of caps to be passed
together with the message. The @{text mi_caps_unwrapped} parameter is a bitmask
allowing threads receiving a message to determine how extra capabilities were
transferred. The @{text mi_label} parameter is transferred directly from sender
to receiver as part of the message.
*}

datatype message_info = MI length_type length_type data msg_label

primrec
  mi_label :: "message_info \<Rightarrow> msg_label"
where
  "mi_label (MI ln exc unw label) = label"

primrec
  mi_length :: "message_info \<Rightarrow> length_type"
where
  "mi_length (MI ln exc unw label) = ln"

primrec
  mi_extra_caps :: "message_info \<Rightarrow> length_type"
where
  "mi_extra_caps (MI ln exc unw label) = exc"

primrec
  mi_caps_unwrapped :: "message_info \<Rightarrow> data"
where
 "mi_caps_unwrapped (MI ln exc unw label) = unw"

text {* Message infos are encoded to or decoded from a data word. *}
primrec
  message_info_to_data :: "message_info \<Rightarrow> data"
where
  "message_info_to_data (MI ln exc unw mlabel) =
   (let
        extra = exc << 7;
        unwrapped = unw << 9;
        label = mlabel << 12
    in
       label || extra || unwrapped || ln)"

text {* Hard-coded to avoid recursive imports? *}
definition
  data_to_message_info :: "data \<Rightarrow> message_info"
where
  "data_to_message_info w \<equiv>
   MI (let v = w && ((1 << 7) - 1) in if v > 120 then 120 else v) ((w >> 7) && ((1 << 2) - 1))
      ((w >> 9) && ((1 << 3) - 1)) (w >> 12)"



section {* Kernel Objects *}

text {* Endpoints are synchronous points of communication for threads. At any
time an endpoint may contain a queue of threads waiting to send, a queue of
threads waiting to receive or be idle. Whenever threads would be waiting to
send and receive simultaneously messages are transferred immediately.
*}

datatype endpoint
           = IdleEP
           | SendEP "obj_ref list"
           | RecvEP "obj_ref list"

text {* AsyncEndpoints are asynchronous points of communication. Unlike regular
endpoints, threads may block waiting to receive but not to send. Whenever a
thread sends to an async endpoint, its message is stored in the endpoint
immediately.
*}

datatype async_ep
           = IdleAEP
           | WaitingAEP "obj_ref list"
           | ActiveAEP badge message


definition
  default_ep :: endpoint where
  "default_ep \<equiv> IdleEP"

definition
  default_async_ep :: async_ep where
  "default_async_ep \<equiv> IdleAEP"


text {* Thread Control Blocks are the in-kernel representation of a thread.

Threads which can execute are either in the Running state for normal execution,
in the Restart state if their last operation has not completed yet or in the
IdleThreadState for the unique system idle thread. Threads can also be blocked
waiting for any of the different kinds of system messages. The Inactive state
indicates that the TCB is not currently used by a running thread.

TCBs also contain some special-purpose capability slots. The CTable slot is a
capability to a CNode through which the thread accesses capabilities with which
to perform system calls. The VTable slot is a capability to a virtual address
space (an architecture-specific capability type) in which the thread runs. If
the thread has issued a Reply cap to another thread and is awaiting a reply,
that cap will have a "master" Reply cap as its parent in the Reply slot. The
Caller slot is used to initially store any Reply cap issued to this thread. The
IPCFrame slot stores a capability to a memory frame (an architecture-specific
capability type) through which messages will be sent and received.

If the thread has encountered a fault and is waiting to send it to its
supervisor the fault is stored in @{text tcb_fault}. The user register file is
stored in @{text tcb_context}, the pointer to the cap in the IPCFrame slot in
@{text tcb_ipc_buffer} and the identity of the Endpoint cap through which faults
are to be sent in @{text tcb_fault_handler}.
*}

record sender_payload =
 sender_badge     :: badge
 sender_can_grant :: bool
 sender_is_call   :: bool

datatype thread_state
  = Running
  | Inactive
  | Restart
  | BlockedOnReceive obj_ref bool
  | BlockedOnSend obj_ref sender_payload
  | BlockedOnReply
  | BlockedOnAsyncEvent obj_ref
  | IdleThreadState

record tcb =
 tcb_ctable        :: cap
 tcb_vtable        :: cap
 tcb_reply         :: cap
 tcb_caller        :: cap
 tcb_ipcframe      :: cap
 tcb_state         :: thread_state
 tcb_fault_handler :: cap_ref
 tcb_ipc_buffer    :: vspace_ref
 tcb_context       :: user_context
 tcb_fault         :: "fault option"


text {* Determines whether a thread in a given state may be scheduled. *}
primrec
  runnable :: "Structures_A.thread_state \<Rightarrow> bool"
where
  "runnable (Running)               = True"
| "runnable (Inactive)              = False"
| "runnable (Restart)               = True"
| "runnable (BlockedOnReceive x y)  = False"
| "runnable (BlockedOnSend x y)     = False"
| "runnable (BlockedOnAsyncEvent x) = False"
| "runnable (IdleThreadState)       = False"
| "runnable (BlockedOnReply)        = False"


definition
  default_tcb :: tcb where
  "default_tcb \<equiv> \<lparr>
      tcb_ctable   = NullCap,
      tcb_vtable   = NullCap,
      tcb_reply    = NullCap,
      tcb_caller   = NullCap,
      tcb_ipcframe = NullCap,
      tcb_state    = Inactive,
      tcb_fault_handler = to_bl (0::word32),
      tcb_ipc_buffer = 0,
      tcb_context    = new_context,
      tcb_fault      = None \<rparr>"

text {*
All kernel objects are CNodes, TCBs, Endpoints, AsyncEndpoints or architecture
specific.
*}
datatype kernel_object
         = CNode nat cnode_contents -- "size in bits, and contents"
         | TCB tcb
         | Endpoint endpoint
         | AsyncEndpoint async_ep
         | ArchObj arch_kernel_obj


text {* Checks whether a cnode's contents are well-formed. *}

definition
  well_formed_cnode_n :: "nat \<Rightarrow> cnode_contents \<Rightarrow> bool" where
 "well_formed_cnode_n n \<equiv> \<lambda>cs. dom cs = {x. length x = n}"

definition
  cte_level_bits :: nat where
  "cte_level_bits  \<equiv> 4"

primrec
  obj_bits :: "kernel_object \<Rightarrow> nat"
where
  "obj_bits (CNode sz cs) = (if well_formed_cnode_n sz cs
                            then cte_level_bits + sz
                            else cte_level_bits)"
| "obj_bits (TCB t) = 9"
| "obj_bits (Endpoint ep) = 4"
| "obj_bits (AsyncEndpoint aep) = 4"
| "obj_bits (ArchObj ao) = arch_kobj_size ao"

primrec
  obj_size :: "cap \<Rightarrow> word32"
where
  "obj_size NullCap = 0"
| "obj_size (UntypedCap r bits f) = 1 << bits"
| "obj_size (EndpointCap r b R) = 1 << obj_bits (Endpoint undefined)"
| "obj_size (AsyncEndpointCap r b R) = 1 << obj_bits (AsyncEndpoint undefined)"
| "obj_size (CNodeCap r bits g) = 1 << (cte_level_bits + bits)"
| "obj_size (ThreadCap r) = 1 << obj_bits (TCB undefined)"
| "obj_size (Zombie r zb n) = (case zb of None \<Rightarrow> 1 << obj_bits (TCB undefined)
                                        | Some n \<Rightarrow> 1 << (cte_level_bits + n))"
| "obj_size (ArchObjectCap a) = 1 << arch_obj_size a"


section {* Kernel State *}

text {* The kernel's heap is a partial function containing kernel objects. *}
type_synonym kheap = "obj_ref \<Rightarrow> kernel_object option"

text {*
Capabilities are created either by cloning an existing capability or by creating
a subordinate capability from it. This results in a capability derivation tree
or CDT. The kernel provides a Revoke operation which deletes all capabilities
derived from one particular capability. To support this, the kernel stores the
CDT explicitly. It is here stored as a tree, a partial mapping from
capability slots to parent capability slots.
*}
type_synonym cdt = "cslot_ptr \<Rightarrow> cslot_ptr option"

datatype irq_state =
   IRQInactive
 | IRQNotifyAEP
 | IRQTimer

text {* The kernel state includes a heap, a capability derivation tree
(CDT), a bitmap used to determine if a capability is the original
capability to that object, a pointer to the current thread, a pointer
to the system idle thread, the state of the underlying machine,
per-irq pointers to cnodes (each containing one async endpoint through which
interrupts are delivered), an array recording which
interrupts are used for which purpose, and the state of the
architecture-specific kernel module.

Note: for each irq, @{text "interrupt_irq_node irq"} points to a cnode which
can contain the async endpoint cap through which interrupts are delivered. In
C, this all lives in a single array. In the abstract spec though, to prove
security, we can't have a single object accessible by everyone. Hence the need
to separate irq handlers.
*}
record abstract_state =
  kheap              :: kheap
  cdt                :: cdt
  is_original_cap    :: "cslot_ptr \<Rightarrow> bool"
  cur_thread         :: obj_ref
  idle_thread        :: obj_ref
  machine_state      :: machine_state
  interrupt_irq_node :: "irq \<Rightarrow> obj_ref"
  interrupt_states   :: "irq \<Rightarrow> irq_state"
  arch_state         :: arch_state

text {* The following record extends the abstract kernel state with extra
state of type @{typ "'a"}. The specification operates over states of
this extended type. By choosing an appropriate concrete type for @{typ "'a"}
we may obtain different \emph{instantiations} of the kernel specifications
at differing levels of abstraction. See \autoref{c:ext-spec} for further
information.
*}
record 'a state = abstract_state + exst :: 'a


text {* This wrapper lifts monadic operations on the underlying machine state to
monadic operations on the kernel state. *}
definition
  do_machine_op :: "(machine_state, 'a) nondet_monad \<Rightarrow> ('z state, 'a) nondet_monad"
where
 "do_machine_op mop \<equiv> do
    ms \<leftarrow> gets machine_state;
    (r, ms') \<leftarrow> select_f (mop ms);
    modify (\<lambda>state. state \<lparr> machine_state := ms' \<rparr>);
    return r
  od"

text {* This function generates the cnode indices used when addressing the
capability slots within a TCB.
*}
definition
  tcb_cnode_index :: "nat \<Rightarrow> cnode_index" where
  "tcb_cnode_index n \<equiv> to_bl (of_nat n :: 3 word)"

text {* Zombie capabilities store the bit size of the CNode cap they were
created from or None if they were created from a TCB cap. This function
decodes the bit-length of cnode indices into the relevant kernel objects.
*}
definition
  zombie_cte_bits :: "nat option \<Rightarrow> nat" where
 "zombie_cte_bits N \<equiv> case N of Some n \<Rightarrow> n | None \<Rightarrow> 3"

lemma zombie_cte_bits_simps[simp]:
 "zombie_cte_bits (Some n) = n"
 "zombie_cte_bits None     = 3"
  by (simp add: zombie_cte_bits_def)+

text {* The first capability slot of the relevant kernel object. *}
primrec
  first_cslot_of :: "cap \<Rightarrow> cslot_ptr"
where
  "first_cslot_of (ThreadCap oref) = (oref, tcb_cnode_index 0)"
| "first_cslot_of (CNodeCap oref bits g) = (oref, replicate bits False)"
| "first_cslot_of (Zombie oref bits n) = (oref, replicate (zombie_cte_bits bits) False)"

text {* The set of all objects referenced by a capability. *}
primrec
  obj_refs :: "cap \<Rightarrow> obj_ref set"
where
  "obj_refs NullCap = {}"
| "obj_refs (ReplyCap r m) = {}"
| "obj_refs IRQControlCap = {}"
| "obj_refs (IRQHandlerCap irq) = {}"
| "obj_refs (UntypedCap r s f) = {}"
| "obj_refs (CNodeCap r bits guard) = {r}"
| "obj_refs (EndpointCap r b cr) = {r}"
| "obj_refs (AsyncEndpointCap r b cr) = {r}"
| "obj_refs (ThreadCap r) = {r}"
| "obj_refs DomainCap = {}"
| "obj_refs (Zombie ptr b n) = {ptr}"
| "obj_refs (ArchObjectCap x) = Option.set (aobj_ref x)"

text {*
  The partial definition below is sometimes easier to work with.
  It also provides cases for UntypedCap and ReplyCap which are not
  true object references in the sense of the other caps.
*}
primrec
  obj_ref_of :: "cap \<Rightarrow> obj_ref"
where
  "obj_ref_of (UntypedCap r s f) = r"
| "obj_ref_of (ReplyCap r m) = r"
| "obj_ref_of (CNodeCap r bits guard) = r"
| "obj_ref_of (EndpointCap r b cr) = r"
| "obj_ref_of (AsyncEndpointCap r b cr) = r"
| "obj_ref_of (ThreadCap r) = r"
| "obj_ref_of (Zombie ptr b n) = ptr"
| "obj_ref_of (ArchObjectCap x) = the (aobj_ref x)"

primrec
  cap_bits_untyped :: "cap \<Rightarrow> nat"
where
  "cap_bits_untyped (UntypedCap r s f) = s"

definition
  "tcb_cnode_map tcb \<equiv>
   [tcb_cnode_index 0 \<mapsto> tcb_ctable tcb,
    tcb_cnode_index 1 \<mapsto> tcb_vtable tcb,
    tcb_cnode_index 2 \<mapsto> tcb_reply tcb,
    tcb_cnode_index 3 \<mapsto> tcb_caller tcb,
    tcb_cnode_index 4 \<mapsto> tcb_ipcframe tcb]"

definition
  "cap_of kobj \<equiv>
   case kobj of CNode _ cs \<Rightarrow> cs | TCB tcb \<Rightarrow> tcb_cnode_map tcb | _ \<Rightarrow> empty"

text {* The set of all caps contained in a kernel object. *}

definition
  caps_of :: "kernel_object \<Rightarrow> cap set" where
  "caps_of kobj \<equiv> ran (cap_of kobj)"

end
