(** A static blog generator. *)

type post =
  { path : string;
    contents: string;
    html: string;
    title: string;
  }

val md_to_post : string -> post
val list_dir : string -> string list

(* (md file path * html) *)
val all_html : string -> (string * string) list
val write_html : string -> (string * string) -> unit

val generate : string -> unit

val post_with_template : string -> post -> string

(* val tt : Omd_representation.element -> string *)
val get_title : Omd.t -> string
