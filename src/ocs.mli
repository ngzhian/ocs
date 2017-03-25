(** A static blog generator. *)

type post =
  { path : string;
    contents: string;
    html: string;
    title: string;
    html_path: string;
    date: Unix.tm;
  }

type site =
  { 
    post_paths : string list;
    posts : post list;
    template: string;
    index_template_path: string;
    index: string;
  }

(** md_dir: directory to find md files (defaults to "./posts")
    template_dir: directory to find template files (defaults to "./template")
    output_dir: directory to write html files (defaults to ".")
*)
type config =
  { md_dir: string;
    template_dir: string;
    output_dir: string;
    use_pandoc: bool;
  }

val md_to_post : string -> bool -> string -> post
val search_for_mds : string -> string list

val generate : config -> unit
val generate_default : unit -> unit

val apply_template : string -> post -> post

val build_site : config -> site
val convert : config -> site -> site
val write : config -> site -> unit
