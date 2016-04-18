open Core.Std

type post =
  { path : string;
    contents: string;
    html: string;
    title: string;
    html_path: string;
  }

type site =
  { post_paths : string list;
    posts : post list;
    template: string;
    index_template_path: string;
    index: string;
  }

type config =
  { md_dir: string;
    template_dir: string;
    output_dir: string;
  }

let get_title md = 
  match md with
  | (Omd.H1 h1) :: _ -> (
    match h1 with
    | (Omd.Text t) :: _ -> t
    | _ -> ""
  )
  | _ -> ""

let is_md path =
  String.is_suffix path ~suffix:".mdown"

let search_for_mds md_dir =
  Sys.ls_dir md_dir
  |> List.filter ~f:is_md

let md_to_post md_dir path =
  let contents = In_channel.read_all (Filename.concat md_dir path) in
  let md = Omd.of_string contents in
  let title = get_title md in
  let html = Omd.to_html (Omd.of_string contents) in
  let html_path = String.chop_suffix_exn path ~suffix:".mdown" ^ ".html" in
  { path; contents; html; title; html_path }

let apply_template template post =
  let open Jg_types in
  let post_model = Tobj [("content", Tstr post.html); ("title", Tstr post.title)] in
  let html = Jg_template.from_string template ~models:[("post", post_model)] in
  { post with html }

let make_output_folder output_dir =
  match Sys.file_exists output_dir with
  | `No -> Unix.mkdir output_dir
  | _ -> ()

let write config site =
  make_output_folder config.output_dir;
  let html_path post = Filename.concat config.output_dir post.html_path in
  let write_html post = Out_channel.write_all (html_path post) ~data:post.html in
  List.iter site.posts ~f:write_html;
  Out_channel.write_all (Filename.concat config.output_dir "index.html") ~data:site.index
  
let build_site config =
  let template_path = Filename.concat config.template_dir "post.html" in
  let template = In_channel.read_all template_path in
  let index_template_path = Filename.concat config.template_dir "index.html" in
  let post_paths = search_for_mds config.md_dir in
  { post_paths; template; posts = []; index_template_path; index = "" }

let build_index site =
  let posts = site.posts in
  let open Jg_types in
  let extract_title_and_html_path post =
    Tobj [("title", Tstr post.title); ("html_path", Tstr post.html_path)] in
  let _posts = List.map posts ~f:extract_title_and_html_path in
  let index = Jg_template.from_file site.index_template_path ~models:[("posts", Tlist _posts)] in
  { site with index }

let convert config site =
  let posts = 
    site.post_paths
    |> List.map ~f:(md_to_post config.md_dir)
    |> List.map ~f:(apply_template site.template) in
  { site with posts }
  |> build_index
  
let generate config =
  build_site config
  |> convert config
  |> write config

let default_config = 
  { md_dir = "."
  ; output_dir = "."
  ; template_dir = Filename.concat "." "template"
  }

let generate_default () =
  generate default_config

let generate_with_dir md_dir template_dir output_dir () =
  generate { md_dir ; output_dir ; template_dir }

(**
 *  Command line interface to ocs.
 *)
let () =
  Command.run ~version:"1.0" (
    Command.basic 
    ~summary:"Generate a static blog from markdown"
    Command.Spec.(
      empty
      +> flag "-m" (optional_with_default (Filename.concat "." "posts") string) ~doc:"directory"
      +> flag "-t" (optional_with_default (Filename.concat "." "tempate") string) ~doc:"directory"
      +> flag "-o" (optional_with_default "." string) ~doc:"directory"
    )
    generate_with_dir
)
