open Core.Std

type post =
  { path : string;
    contents: string;
    html: string;
    title: string;
  }

let get_title md = 
  match md with
  | (Omd.H1 h1) :: _ -> (
    match h1 with
    | (Omd.Text t) :: _ -> t
    | _ -> ""
  )
  | _ -> ""

let md_to_post path =
  let contents = In_channel.read_all path in
  let md = Omd.of_string contents in
  let title = get_title md in
  let html = Omd.to_html (Omd.of_string contents) in
  { path = "asdf"; contents; html; title; }
;;

(**
 From a dir, get a list of all md files (fqn)
*)
let list_dir dir =
  let is_md path = String.is_suffix path ~suffix:".md" in
  Sys.ls_dir dir
  |> List.filter ~f:is_md

let post_with_template template post =
  let re = Str.regexp "{{BODY}}" in
  Str.replace_first re post.html template
  |> Str.replace_first (Str.regexp "{{TITLE}}") post.title

let all_html dir = 
  let template_path = Filename.concat dir "post.html" in
  let template = In_channel.read_all template_path in
  let apply_template = fun post -> post_with_template template post in
  let all_mds = list_dir dir in
  all_mds
  |> List.map ~f:md_to_post
  |> List.map ~f:apply_template 
  |> List.zip_exn all_mds

let write_html dir (path, html) =
  let html_path = String.chop_suffix_exn path ~suffix:".md" ^ ".html" in
  Out_channel.write_all (Filename.concat dir html_path) ~data:html

let generate dir =
  let htmls = all_html dir in
  let write = write_html dir in
  List.iter htmls ~f:write
