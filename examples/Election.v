From CTree Require Import
  CTree.Core
  Logic.Ctl
  Utils.Vectors
  Events.WriterE
  CTree.Logic.Trans
  CTree.Logic.AF
  CTree.Equ
  CTree.Events.Writer
  CTree.Events.Net.

From Coq Require Import
  Fin
  Vector
  List
  Classes.SetoidClass.

Set Implicit Arguments.

Import ListNotations CTreeNotations CtlNotations MessageOrderScheduler.
Local Close Scope list_scope.
Local Open Scope ctree_scope.
Local Open Scope fin_vector_scope.
Local Open Scope ctl_scope.

Section Election.
  Context {n: nat}.
  Variant message :=
    | Candidate (u: fin' n)
    | Elected (u: fin' n).

  Notation netE := (netE n message).

  Definition msg_id(m: message): fin' n :=
    match m with
    | Candidate u => u
    | Elected u => u
    end.

  Definition eqb_message(a b: message): bool :=
    match a, b with
    | Candidate a, Candidate b => Fin.eqb a b
    | Elected a, Elected b => Fin.eqb a b
    | _, _ => false
    end.

  Notation continue := (Ret (inl tt)).
  Notation stop := (Ret (inr tt)).

  (* Always terminates, conditional on receiving either:
     1. (Candidate candidate), where candidate = id -- I received my own [id] back 
     2. (Elected leader) -- Someone else was elected [leader]

    If scheduled fairly, either 1, 2 should always eventually happen.
    Should be WG provable.
  *)
  Definition proc(id: fin' n): ctree netE (fin' n) :=
    let right := cycle id in
    send right (Candidate id) ;;
    Ctree.iter
      (fun _ =>
         m <- recv ;;
         match m with
         | Some (Candidate candidate) =>
             match Fin_compare candidate id with (* candidate < id *)
             (* [left] neighbor proposed candidate, support her to [right]. *)
             | Gt => send right (Candidate candidate) ;; continue
             (* [left] neighbor proposed a candidate, do not support her. *)
             | Lt => continue
             (* I am the leader, but only I know. Tell my [right] and return. *)
             | Eq => send right (Elected id) ;; Ret (inr id)
             end
         | Some (Elected leader) =>
             (* I am a follower and know the [leader] *)
             send right (Elected leader) ;; Ret (inr leader)
         | None => continue (* Recv loop *)
         end) tt.

  (* TODO: Instrumentation of [send] *)
  Definition instr(i: fin' n)(mail: message) : option (fin' n) := Some i.
  

  Definition election_interp : ctree (writerE (fin' n)) void :=
    schedule instr (Vector.map proc (fin_all_v n)).

  Lemma election_fair: forall (i: fin' n),
      <( election_interp, Pure |= AF visW \j, i = j )>.
  Proof.
    intros.
    unfold election_interp, schedule.
    unfold Ctree.branch.
    rewrite bind_br.
    apply af_br.
    intro j. (* First pick *)
    rewrite bind_ret_l.
    
End Election.
