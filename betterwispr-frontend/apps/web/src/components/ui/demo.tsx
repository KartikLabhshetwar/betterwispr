import Testimonials, { type Testimonial } from "./cards";

// Stock portraits and fictional sample copy. Never use as customer endorsements.
const SAMPLE_TESTIMONIALS: Testimonial[] = [
  { name: "Sample author", handle: "@sample", quote: "A quick thought, straight into the app I’m already using.", image: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=96&h=96&q=80", postUrl: "" },
  { name: "Sample author", handle: "@sample", quote: "My favorite part? Choosing a local model and keeping my words on my Mac.", image: "https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=96&h=96&q=80", postUrl: "" },
  { name: "Sample author", handle: "@sample", quote: "Hold a shortcut. Say the thing. Keep going.", image: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=96&h=96&q=80", postUrl: "" },
  { name: "Sample author", handle: "@sample", quote: "I added my project names to the vocabulary. That little detail makes a difference.", postUrl: "" },
  { name: "Sample author", handle: "@sample", quote: "For the moments when I know what I want to say but don’t feel like typing it all out.", postUrl: "" },
  { name: "Sample author", handle: "@sample", quote: "A small tool that fits into the way I already work.", postUrl: "" },
];

export default function TestimonialsDemo() {
  return <Testimonials testimonials={SAMPLE_TESTIMONIALS} preview />;
}
