/* eslint-disable react/prop-types */
import React, { createRef, CSSProperties, useEffect, useState } from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { CapiVariable } from '../types/parts';

const Carousel: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }
    props.onInit({
      id,
      responses: [
        {
          key: `Sim Options.Mode`,
          type: CapiVariableTypes.STRING,
          value: mode,
        },
        {
          key: `customCss`,
          type: CapiVariableTypes.STRING,
          value: customCss,
        },
        {
          key: `zoom`,
          type: CapiVariableTypes.BOOLEAN,
          value: zoom,
        },
      ],
    });
    setReady(true);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const {
    x,
    y,
    z,
    width,
    height,
    cssClasses = '',
    fontSize = 16,
    showOnAnswersReport = false,
    requireManualGrading = false,
    mode = 'Student',
    images = [],
    customCss = '',
    zoom = false,
  } = model;

  const [imagesLoaded, setImagesLoaded] = useState(false);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [viewedSlides, setViewedSlides] = useState<any[]>([]);
  const [captionRefs, setCaptionRefs] = useState<any[]>([]);
  const [carouselCustomCss, setCarouselCustomCss] = useState<string>(customCss);
  const [carouselMode, setCarouselMode] = useState<string>(mode);
  const [carouselZoom, setCarouselZoom] = useState<boolean>(zoom);
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const carouselDefaultCss = require('./Carousel.css');
  const MAGIC_NUMBER = 64;
  const PAGINATION_HEIGHT = 32;
  const styles: CSSProperties = {
    position: 'absolute',
    top: `${y}px`,
    left: `${x}px`,
    width: `${width}px`,
    height: `${height}px`,
    fontSize: `${fontSize}px`,
    zIndex: z,
    overflow: 'hidden',
    display: 'flex',
  };
  const imgStyles: CSSProperties = {
    maxWidth: `calc(${width}px - ${MAGIC_NUMBER}px)`,
    maxHeight: imagesLoaded
      ? `calc(${height}px - ${captionRefs[currentSlide]?.current?.clientHeight}px - ${PAGINATION_HEIGHT}px)`
      : `calc(${height} - ${MAGIC_NUMBER}px)`,
  };

  useEffect(() => {
    // when images[] load, refs are set on captions in order to calc() max-height for each image later
    if (images && images.length > 0) {
      setCaptionRefs((captionRefs) =>
        Array(images.length)
          .fill(images.length)
          .map((_, i) => captionRefs[i] || createRef()),
      );
    }
  }, [images]);

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const saveState = ({
    carouselMode,
    carouselCustomCss,
    carouselZoom,
  }: {
    carouselMode: string;
    carouselCustomCss: string;
    carouselZoom: boolean;
  }) => {
    const vars: any = [];
    const viewedImagesCount = [...new Set(viewedSlides)].length;
    const currentImage = currentSlide + 1;

    vars.push({
      key: `Sim Options.Mode`,
      type: CapiVariableTypes.STRING,
      value: carouselMode,
    });
    vars.push({
      key: `Current Image`,
      type: CapiVariableTypes.NUMBER,
      value: currentImage,
    });
    vars.push({
      key: `Viewed Images Count`,
      type: CapiVariableTypes.NUMBER,
      value: viewedImagesCount,
    });
    vars.push({
      key: `customCss`,
      type: CapiVariableTypes.STRING,
      value: carouselCustomCss,
    });
    vars.push({
      key: `zoom`,
      type: CapiVariableTypes.BOOLEAN,
      value: carouselZoom,
    });
    props.onSave({
      id: `${id}`,
      responses: vars,
    });
  };

  const handleStateChange = (data: CapiVariable[]) => {
    // override various things from state
    const stateVariables: any = {
      carouselMode: mode,
      carouselCustomCss: customCss,
      carouselZoom: zoom,
    };
    const interested = data.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
    interested.forEach((stateVar) => {
      if (stateVar.key === 'Mode') {
        setCarouselMode(stateVar.value as string);
        stateVariables.carouselMode = stateVar.value as string;
      }
      if (stateVar.key === 'customCss') {
        setCarouselCustomCss(stateVar.value as string);
        stateVariables.carouselCustomCss = stateVar.value as string;
      }
      if (stateVar.key === 'zoom') {
        setCarouselZoom(stateVar.value as boolean);
        stateVariables.carouselZoom = stateVar.value as boolean;
      }
    });
    saveState(stateVariables);
  };

  useEffect(() => {
    saveState({
      carouselMode: mode,
      carouselCustomCss: customCss,
      carouselZoom: zoom,
    });
  }, [currentSlide]);

  const handleSlideChange = (currentSlide: any) => {
    setViewedSlides((viewedSlides) => [...viewedSlides, currentSlide]);
    setCurrentSlide(currentSlide);
  };

  return (
    <div
      data-janus-type={props.type}
      id={id}
      className={`janus-image-carousel ${cssClasses}`}
      style={styles}
    >
      {customCss && (
        <style type="text/css" style={{ display: 'none' }}>
          {carouselDefaultCss}
          {carouselCustomCss ? carouselCustomCss : null}
        </style>
      )}
      {images.length > 0 && (
        <Swiper
          slidesPerView={1}
          loop
          navigation
          zoom={zoom ? { maxRatio: 3 } : false}
          keyboard={{ enabled: true }}
          pagination={{ clickable: true }}
          onSwiper={(swiper) => {
            setCurrentSlide(swiper.realIndex);
          }}
          onSlideChange={(swiper) => {
            handleSlideChange(swiper.realIndex);
          }}
          onImagesReady={() => {
            setImagesLoaded(true);
          }}
        >
          {images.map((image: any, index: number) => (
            <SwiperSlide key={index} zoom={zoom}>
              <figure className="swiper-zoom-container">
                <img style={imgStyles} src={image.url} alt={image.alt ? image.alt : undefined} />
                <figcaption ref={captionRefs[index]}>{image.caption}</figcaption>
              </figure>
            </SwiperSlide>
          ))}
        </Swiper>
      )}
      {images.length <= 0 && <div className="no-images">No images to display</div>}
    </div>
  );
};

export const tagName = 'janus-carousel';

export default Carousel;
