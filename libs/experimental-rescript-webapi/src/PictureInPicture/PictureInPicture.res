type t = PictureInPictureTypes.pictureInPictureWindow = {
  ...PictureInPictureTypes.pictureInPictureWindow,
}

include EventTarget.Impl({type t = t})

module Types = PictureInPictureTypes
