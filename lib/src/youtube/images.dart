class ImageObject {
  final Uri url;
  final int width;
  final int height;

  ImageObject.fromJson(Map<String, dynamic> data)
      : url = Uri.parse(data["url"]).replace(scheme: "https"),
        width = data["width"],
        height = data["height"];
}
